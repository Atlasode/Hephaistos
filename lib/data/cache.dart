import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/data.dart';

typedef SchemeFactory<S> = S Function(DataObject object);
typedef CachedWidgetBuilder = Widget Function(BuildContext context, CacheData cache);
typedef CollectionWhere = Query Function(Query query);
typedef KeyGetter<S extends ObjectScheme> = List<String> Function(S scheme);
typedef CollectionListener = void Function(List<DataObject> cache);
typedef DocumentListener = void Function(DataObject cache);

class CacheData {
  final Node _node;
  final dynamic _data;

  const CacheData(this._data, this._node);

  S asScheme<S extends ObjectScheme>(CollectionKey<S> key) {
    assert(_data is DataObject);
    return (_data as DataObject).as(key);
  }

  S asSchemeOrNull<S extends ObjectScheme>(CollectionKey<S> key) {
    if (_data == null || (_data is DataObject && (_data as DataObject).doc.data == null)) {
      return null;
    }
    assert(_data is DataObject);
    return (_data as DataObject).as(key);
  }

  List<S> asList<S extends ObjectScheme>(CollectionKey<S> key) {
    assert(_data is List);
    if ((_data as List).length == 0) {
      return [];
    }
    assert(_data is List<DataObject>);
    return (_data as List<DataObject>).map<S>((obj) => obj.as(key)).toList();
  }

  N node<N extends Node>() {
    return _node as N;
  }

  Document doc(){
    return _node as Document;
  }

  Collection col(){
    return _node as Collection;
  }
}

abstract class StreamHandler<T> {
  void clear();

  void update(T data);

  void clearData();
}

class StreamProvider<T> {
  final Node parent;
  final Stream<T> stream;
  StreamSubscription<dynamic> listener;
  int listenerCount;
  Collection controller;

  StreamProvider(this.parent, [this.stream = const Stream.empty()])
      : listenerCount = 0;

  void control(Collection controller) {
    this.controller = controller;
    if (listener != null) {
      listener.cancel();
    }
  }

  void decontrol() {
    if (listener != null) {
      listener = stream.listen((data) {
        parent.update(data);
      });
    } else {
      parent.clearData();
    }
  }

  void subscribe() {
    listenerCount += 1;
    if (listener == null) {
      listener = stream.listen((data) {
        parent.update(data);
      });
    }
  }

  void unsubscribe() {
    assert(listenerCount > 0);
    if (listenerCount > 1) {
      listenerCount -= 1;
    } else if (listenerCount == 1) {
      listener.cancel();
      listener = null;
      listenerCount = 0;
      parent.clearData();
    }
  }
}

abstract class Node<T, R> {
  StreamProvider<T> _provider;
  final R reference;

  Node(this.reference) {
    _provider = StreamProvider<T>(this, reference is DocumentReference ? (reference as DocumentReference).snapshots() : reference is Query ? (reference as Query).snapshots() : Stream.empty());
  }

  /// Calls 'unsubscribe()' on all children and clears the children list.
  void clear();

  void update(T data);

  void clearData();

  void control(Collection controller) {
    _provider.control(controller);
  }

  void decontrol() {
    _provider.decontrol();
  }

  void subscribe() {
    _provider.subscribe();
  }

  void unsubscribe() {
    _provider.unsubscribe();
  }

 /* void _updateProvider(R reference){
    Collection controller = this.controller;
    if(controller == null){
      unsubscribe();
    }
    _provider = StreamProvider<T>(this, reference is DocumentReference ? reference.snapshots() : reference is Query ? reference.snapshots() : Stream.empty());
    if(controller != null){
      _provider.controller = controller;
    }
  }*/

  Stream<T> get stream =>_provider.stream;

  StreamSubscription<dynamic> get listener =>_provider.listener;

  Collection get controller=>_provider.controller;
}

abstract class FilterProvider<P> {
  final String siblingKey;

  const FilterProvider(this.siblingKey);

  Query getQuery(Query collection){
    return needsSibling() ? handleQuery(collection) : collection;
  }

  Query handleQuery(Query query);
  bool needsUpdate(P oldProvider);
  bool needsSibling();
}

class Collection extends Node<QuerySnapshot, Query> {
  /// The path of the collection in the database.
  final String path;

  /// Documents are the children and entries of this collection.
  final Map<String, Document> documents;

  /// Siblings are versions of the same collection but with filters applied to them. Every sibling needs a special key to represent its filters.
  final Map<String, Collection> siblings;

  /// The values of all child documents of this collection, used so we only need one collection stream and not one for every document too.
  final List<DataObject> childValues;

  /// These are used to keep the filtered entries up to date.
  final Map<String, DocumentListener> dependencies;

  /// All listeners of this collection.
  final Set<CollectionListener> listeners;

  /// True if this collection is subscribed to a stream and updates ('controls') the values of its documents.
  bool controlled;

  final FilterProvider filter;

  Collection(this.path, {this.filter})
      : documents = {},
        dependencies = {},
        childValues = [],
        siblings = {},
        listeners = Set(),
        super(filter != null ? filter.getQuery(Firestore.instance.collection(path)) : Firestore.instance.collection(path));

  Collection where(FilterProvider provider) {
    String key = provider.siblingKey;
    Collection sibling = siblings[key];
    if(sibling == null || provider.needsUpdate(sibling.filter)){
      sibling = Collection(path, filter: provider);
      siblings[key] = sibling;
      return sibling;
    }
    return sibling;
  }

  void enableControl() {
    documents.forEach((key, value) => value.control(this));
    controlled = true;
  }

  void disableControl() {
    documents.forEach((key, value) => value.decontrol());
    controlled = false;
  }

  Function() listen(CollectionListener listener) {
    listeners.add(listener);
    return () => listeners.remove(listener);
  }

  @override
  void clear() {
    documents.forEach((key, doc) => doc.clear());
    childValues.clear();
  }

  void subscribe() {
    if (listener == null) {
      enableControl();
    }
    super.subscribe();
  }

  void unsubscribe() {
    super.unsubscribe();
    if (listener == null) {
      disableControl();
    }
  }

  void disposeChild(String location) {
    var removeChild = documents.remove(location);
    if (removeChild != null) {
      removeChild.unsubscribe();
    }
  }

  void dispose() {
    documents.forEach((key, storage) => storage.unsubscribe());
  }

  @override
  void clearData() {
    childValues.clear();
  }

  @override
  void update(QuerySnapshot data) {
    childValues.clear();
    data.documents.forEach((doc) {
      Document cache = document(doc.documentID);
      if (cache.controller == null) {
        cache.control(this);
      }
      cache.update(doc);
      childValues.add(cache.dataCache);
    });
    listeners.forEach((listener) => listener(childValues));
  }

  Document document(String location) {
    return documents.putIfAbsent(location, () => Document(this.path + '/' + location));
  }

  Future<CacheData> requestUpdate() async {
    QuerySnapshot snapshot = await reference.getDocuments();
    update(snapshot);
    return CacheData(childValues, this);
  }
}

/// Represents a document in the firestore database and caches the data of this database in the 'dataCache' variable
class Document extends Node<DocumentSnapshot, DocumentReference> {
  /// The path of the document in the database.
  final String path;

  /// A map with all collections of this document
  final Map<String, Collection> collections;

  /// All listeners of this document
  final Set<DocumentListener> listeners;

  /// If this document is the root document of the current collection-document tree
  final bool root;

  /// The currently cached data object of this document
  DataObject dataCache;

  Document(this.path, {this.root = false})
      : collections = {},
        listeners = {},
        super(Firestore.instance.document(path));

  String get documentID => path.split('/').last;

  Collection collection<S>(CollectionKey<S> key) {
    return collections.putIfAbsent(key.subPath, () => Collection(root ? key.subPath : this.path + '/' + key.subPath));
  }

  Document document<S>(CollectionKey<S> key, String subPath) {
    return collection(key).document(subPath);
  }

  Collection getCollection(String path) {
    assert(path != null && path.length % 2 == 0);
    List<String> pathComponent = path.split('/');
    return subCollection(collections, pathComponent, 0);
  }

  Document getDocument(String path) {
    assert(path != null && path.length % 2 == 1);
    List<String> pathComponent = path.split('/');
    return subCollection(collections, pathComponent, 0).document(pathComponent.last);
  }

  Collection subCollection(Map<String, Collection> collections, List<String> pathComponent, int index) {
    if (pathComponent.length == index || (pathComponent.length - index) == 1) {
      return collections[pathComponent[index]];
    }
    return subCollection(collections[pathComponent[index]].document(pathComponent[index + 1]).collections, pathComponent, index + 2);
  }

  Function() listen(DocumentListener listener) {
    listeners.add(listener);
    return () => listeners.remove(listener);
  }

  @override
  void update(DocumentSnapshot data) {
    this.dataCache = DataObject(this, data);
    listeners.forEach((listener)=>listener(dataCache));
  }

  @override
  void clearData() {
    this.dataCache = null;
  }

  Future<CacheData> requestUpdate() async {
    DocumentSnapshot snapshot = await reference.get();
    update(snapshot);
    return CacheData(dataCache, this);
  }

  @override
  void clear() {
    clearData();
    collections.forEach((key, collection) => collection.clear());
  }

  Future<void> _set(Transaction transaction, DataObject data) => transaction.set(reference, data.asDatabase());

  Future<void> _update(Transaction transaction, DataObject data) => transaction.update(reference, data.asChanges());

  Future<void> _delete(Transaction transaction) => transaction.delete(reference);
}

class Writer {
  final Transaction transaction;

  Writer._(this.transaction);

  updateOrCreate(Document doc, DataObject data(DataObject oldData), {bool update = false}) {
    if (update) {
      this.update(doc, data);
    } else {
      set(doc, data);
    }
  }

  set(Document doc, DataObject data(DataObject oldData)) {
    doc._set(transaction, data(doc.dataCache));
  }

  update(Document doc, DataObject data(DataObject oldData)) {
    doc._update(transaction, data(doc.dataCache));
  }

  delete(Document doc) {
    doc._delete(transaction);
  }

  static Future<void> start(Future<void> handleWriting(Writer writer)) {
    return Firestore.instance.runTransaction((transaction) async => await handleWriting(Writer._(transaction)));
  }
}

class CollectionKey<S> {
  final String subPath;
  final SchemeFactory<S> schemeFactory;

  const CollectionKey(this.subPath, this.schemeFactory);
}

List<String> dynamicToList(Iterable<dynamic> dynamicList) {
  return dynamicList == null ? [] : dynamicList.map((value) => value.toString()).toList();
}

Map<String, String> dynamicToMap(dynamic dynamicMap) {
  return (dynamicMap == null || dynamicMap is Map) ? {} : dynamicMap.map((key, value) => MapEntry(key.toString(), value.toString()));
}

class Caches {
  static Document document = Document('', root: true);
  static CollectionKey<Group> groups = CollectionKey('groups', (doc) => Group(doc));
  static CollectionKey<User> users = CollectionKey('users', (doc) => User(doc));

  static Document userDocument() {
    return Caches.document.document(users, defaultUser);
  }

  static Document groupDocument<S>({CollectionKey<S> key, String path}) {
    if (key != null && path != null) {
      return Caches.document.document(Caches.groups, debugGroup).document(key, path);
    }
    return Caches.document.document(Caches.groups as CollectionKey<S>, debugGroup);
  }

  static Collection groupCollection<S>(CollectionKey<S> key) {
    return Caches.document.document(Caches.groups, debugGroup).collection(key);
  }
}

class GroupCache {
  static CollectionKey<Subject> subjects = CollectionKey('subjects', (doc) => Subject(doc));
  static CollectionKey<Course> courses = CollectionKey('courses', (doc) => Course(doc));
  static CollectionKey<Timetable> timetables = CollectionKey('timetables', (doc) => Timetable(doc));
  static CollectionKey<Named> persons = CollectionKey('persons', (doc) => Named(doc));
  static CollectionKey<Room> rooms = CollectionKey('rooms', (doc) => Room(doc));
}

class CachedDocument extends StatefulWidget {
  final CachedWidgetBuilder customWaiting;
  final CachedWidgetBuilder builder;
  final Document storage;

  CachedDocument({Key key, String path, this.customWaiting, this.builder, Document document})
      : assert(path != null || document != null),
        assert(builder != null),
        storage = document != null ? document : Caches.document.getDocument(path),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _CachedDocumentState();
}

class _CachedDocumentState extends State<CachedDocument> {
  @override
  void initState() {
    super.initState();
    widget.storage.subscribe();
  }

  @override
  void didUpdateWidget(CachedDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storage != widget.storage) {
      oldWidget.storage.unsubscribe();
      widget.storage.subscribe();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.storage.stream,
        builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> currentSummary) {
          if (currentSummary.hasError) return new Text('Error: ${currentSummary.error}');
          if (currentSummary.connectionState == ConnectionState.waiting) {
            if (widget.customWaiting != null) {
              return widget.customWaiting(context, new CacheData(widget.storage.dataCache, widget.storage));
            } else {
              return CircularProgressIndicator();
            }
          }
          return widget.builder(context, new CacheData(widget.storage.dataCache, widget.storage));
        });
  }

  @override
  void dispose() {
    widget.storage.unsubscribe();
    super.dispose();
  }
}

class FilteredQuery<C> extends StatelessWidget {
  final CachedWidgetBuilder customWaiting;
  final CachedWidgetBuilder builder;
  final Collection collection;
  final bool Function() filterPredicate;

  const FilteredQuery({Key key, this.customWaiting, this.builder, this.collection, this.filterPredicate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (filterPredicate()) {
      return CachedQuery(
        collection: collection,
        customWaiting: customWaiting,
        builder: builder,
      );
    }
    return builder(context, new CacheData(<CacheData>[], collection));
  }
}

class KeyProvider extends FilterProvider<KeyProvider> {
  final List<String> keys;

  const KeyProvider(String siblingKey, [this.keys = EMPTY_STRING_LIST]) : super(siblingKey);

  @override
  Query handleQuery(Query query) {
    return query.where(FieldPath.documentId, whereIn: keys);
  }

  @override
  bool needsSibling() {
    return keys != null && keys.length > 0;
  }

  @override
  bool needsUpdate(KeyProvider oldProvider) {
    return oldProvider.keys == null && keys != null
        || oldProvider.keys != null && keys == null
        || oldProvider.keys != null && keys != null && (oldProvider.keys.length != keys.length || oldProvider.keys != keys);
  }
}

class FilteredGroupCollection<S extends ObjectScheme, C extends ObjectScheme> extends StatelessWidget {
  final S scheme;
  final String schemeDocumentId;
  final KeyGetter<S> keyGetter;
  final CollectionKey<C> collection;
  final CachedWidgetBuilder customWaiting;
  final CachedWidgetBuilder builder;

  const FilteredGroupCollection({Key key, this.scheme, this.schemeDocumentId, this.keyGetter, this.collection, this.customWaiting, this.builder}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Collection col = Caches.groupCollection(collection);
    List<String> keys = keyGetter(scheme);
    KeyProvider provider = KeyProvider('keysIn=' + schemeDocumentId, keys);
    return FilteredQuery(
      collection: scheme == null
          ? col
          : col.where(provider),
      filterPredicate: () => keys != null && keys.length > 0,
      builder: builder,
      customWaiting: customWaiting,
    );
  }
}

class CachedQuery extends StatefulWidget {
  final CachedWidgetBuilder customWaiting;
  final CachedWidgetBuilder builder;
  final Collection collection;

  CachedQuery({Key key, String path, this.customWaiting, this.builder, Collection collection})
      : assert(path != null || collection != null),
        assert(builder != null),
        collection = collection != null ? collection : Caches.document.getCollection(path),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _CachedQueryState();
}

class _CachedQueryState extends State<CachedQuery> {
  @override
  void initState() {
    super.initState();
    widget.collection.subscribe();
  }

  @override
  void didUpdateWidget(CachedQuery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.collection != widget.collection) {
      oldWidget.collection.unsubscribe();
      widget.collection.subscribe();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: widget.collection.stream,
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> currentSummary) {
          if (currentSummary.hasError) return new Text('Error: ${currentSummary.error}');
          if (currentSummary.connectionState == ConnectionState.waiting) {
            if (widget.customWaiting != null) {
              return widget.customWaiting(context, new CacheData(widget.collection.childValues, widget.collection));
            } else {
              return CircularProgressIndicator();
            }
          }
          return widget.builder(context, new CacheData(widget.collection.childValues, widget.collection));
        });
  }

  @override
  void dispose() {
    widget.collection.unsubscribe();
    super.dispose();
  }
}
