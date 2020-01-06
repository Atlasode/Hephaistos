import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/data/cache.dart';

typedef ValueFromDoc<C> = C Function(String propertyName, DocumentSnapshot doc);
typedef ValueToDynamic<C> = dynamic Function(String propertyName, C value);

class Day {
  final String name;
  final int index;

  const Day._internal(this.name, this.index);

  toString() => name;

  short() => '${name.toUpperCase()[0]}${name.substring(1, 3)}';

  static const monday = const Day._internal('monday', 0);
  static const tuesday = const Day._internal('tuesday', 1);
  static const wednesday = const Day._internal('wednesday', 2);
  static const thursday = const Day._internal('thursday', 3);
  static const friday = const Day._internal('friday', 4);
  static const saturday = const Day._internal('saturday', 5);
  static const sunday = const Day._internal('sunday', 6);
  static const List<Day> values = const [monday, tuesday, wednesday, thursday, friday, saturday, sunday];
}

Map<String, Day> _dayByName;

Day dayByName(String name) {
  if (_dayByName == null) {
    _dayByName = Map.fromIterable(Day.values, key: (day) => day.name);
  }
  return _dayByName[name];
}

class Property<C> {
  final ValueFromDoc<C> serializer;
  final ValueToDynamic<C> deserializer;

  Property(this.serializer, {ValueToDynamic<C> deserializer}) : deserializer = deserializer ?? ((String propertyName, C value) => value as dynamic);

  dynamic deserialize(String propertyName, dynamic value) {
    return deserializer(propertyName, value as C);
  }
}

class Properties {
  static Property<String> string = Property((String propertyName, DocumentSnapshot doc) => doc[propertyName]);
  static Property<List<String>> stringList = Property((String propertyName, DocumentSnapshot doc) => _stringList(doc[propertyName]));
  static Property<Map<String, String>> stringMap = Property((String propertyName, DocumentSnapshot doc) => _stringMap(doc[propertyName]));
  static Property<bool> boolean = Property((String propertyName, DocumentSnapshot doc) => doc[propertyName] as bool);
  static Property<Map<String, bool>> boolMap = Property((String propertyName, DocumentSnapshot doc) => _boolMap(doc[propertyName]));
  static Property<int> integer = Property((String propertyName, DocumentSnapshot doc) => doc[propertyName] as int);
  static Property<List<Lessons>> lessonsList = Property((String propertyName, DocumentSnapshot doc) {
    List dynamicList = doc[propertyName] as List;
    return dynamicList.map<Lessons>((dyn) => Lessons(dyn)).toList().cast();
  }, deserializer: (String propertyName, List<Lessons> value) {
    return value.map<Map<String, dynamic>>((value) => value.toMap()).toList();
  });
  static Property<Color> color = Property((String propertyName, DocumentSnapshot doc) {
    dynamic colorCode = doc[propertyName];
    if (colorCode == null) {
      return Colors.white;
    }
    return Color(int.tryParse(colorCode));
  }, deserializer: (propertyName, Color colorValue)=>'0x${colorValue.value.toRadixString(16)}');
}

class ObjectScheme {
  final DataObject object;

  ObjectScheme(this.object);

  static Attribute<C> att<C>(DataObject object, String name, Property<C> property) {
    return object.attributes.putIfAbsent(name, () => Attribute<C>(name, property));
  }
}

class Attribute<C> {
  final Property<C> property;
  final String name;
  bool updated;
  C value;

  Attribute(this.name, this.property) : updated = false;

  void set(C value, {forceUpdate = false}) {
    if(value != this.value || forceUpdate) {
      updated = true;
      this.value = value;
    }
  }

  C get({fallback}) {
    if(value == null){
      return fallback;
    }
    return value;
  }
}

class DataObject {
  final Document document;
  final Map<String, Attribute> attributes;
  final DocumentSnapshot doc;

  DataObject(this.document, this.doc) : attributes = {};

  void parse() {
    if(doc == null || doc.data == null || doc.data.length == 0){
      return;
    }
    attributes.forEach((name, attribute) {
      Attribute attribute = attributes[name];
      attribute.value = attribute.property.serializer(name, doc);
    });
  }

  S as<S>(CollectionKey<S> key) {
    S value = key.schemeFactory(this);
    parse();
    return value;
  }

  Map<String, dynamic> asDatabase() {
    return attributes.map((name, attribute) => MapEntry(name, attribute.property.deserialize(name, attribute.value)));
  }

  Map<String, dynamic> asChanges() {
    Map<String, dynamic> database = asDatabase();
    database.removeWhere((name, value) => !attributes[name].updated);
    return database;
  }
}

List<String> _stringList(Iterable<dynamic> dynamicList) {
  return dynamicList == null ? [] : dynamicList.map<String>((value) => value.toString()).toList();
}

Map<String, String> _stringMap(Map dynamicMap) {
  return (dynamicMap == null || dynamicMap is! Map) ? {} : dynamicMap.map<String, String>((key, value) => MapEntry(key.toString(), value.toString()));
}

Map<String, bool> _boolMap(dynamic dynamicMap) {
  return (dynamicMap == null || dynamicMap is! Map) ? {} : dynamicMap.map<String, bool>((key, value) => MapEntry(key.toString(), value as bool));
}

class Named extends ObjectScheme {
  final Attribute<String> key;
  final Attribute<String> name;
  final Attribute<String> short;
  final Attribute<Color> color;

  Named(DataObject object)
      : key = ObjectScheme.att(object, 'key', Properties.string),
        name = ObjectScheme.att(object, 'name', Properties.string),
        short = ObjectScheme.att(object, 'short', Properties.string),
        color = ObjectScheme.att(object, 'color', Properties.color),
        super(object);
}

class Room extends Named {
  final Attribute<String> address;

  Room(DataObject object)
      : address = ObjectScheme.att(object, 'address', Properties.string),
        super(object);
}

class Subject extends Named {
  final Attribute<List<String>> courses;
  final Attribute<bool> mandatory;

  Subject(DataObject object)
      : courses = ObjectScheme.att(object, 'courses', Properties.stringList),
        mandatory =  ObjectScheme.att(object, 'mandatory', Properties.boolean),
        super(object);
}

class Course extends Named {
  final Attribute<List<String>> persons;
  final Attribute<List<String>> rooms;
  final Attribute<String> subjectKey;

  Course(DataObject object)
      : persons = ObjectScheme.att(object, 'persons', Properties.stringList),
        rooms = ObjectScheme.att(object, 'rooms', Properties.stringList),
        subjectKey = ObjectScheme.att(object, 'subjectKey', Properties.string),
        super(object);
}

class Group extends ObjectScheme {
  final Attribute<String> key;
  final Attribute<String> name;

  Group(DataObject object)
      : key = ObjectScheme.att(object, 'key', Properties.string),
        name = ObjectScheme.att(object, 'name', Properties.string),
        super(object);
}

class User extends ObjectScheme {
  final Attribute<String> key;
  final Attribute<String> name;
  final Attribute<String> timetable;
  final Attribute<Map<String, String>> courses;

  User(DataObject object)
      : key = ObjectScheme.att(object, 'key', Properties.string),
        name = ObjectScheme.att(object, 'name', Properties.string),
        timetable = ObjectScheme.att(object, 'timetable', Properties.string),
        courses = ObjectScheme.att(object, 'courses', Properties.stringMap),
        super(object);

  /// Returns a list with all subjects that have not course selected for this user.
  Future<List<String>> getMissingSubjects(Group group) async {
    return Caches.groupCollection(GroupCache.subjects).requestUpdate().then((subjectsCache) {
      List<Subject> subjects = subjectsCache.asList(GroupCache.subjects);
      return subjects.map((subjectCache) => subjectCache.name.value).where((subjectName) => courses.get().containsKey(subjectName)).toList();
    });
  }
}

class Timetable extends ObjectScheme {
  final Attribute<String> key;
  final Attribute<String> name;
  final Attribute<int> lessonsCount;
  final Attribute<Map<String, bool>> days;
  final Attribute<List<Lessons>> lessons;

  Timetable(DataObject object)
      : key = ObjectScheme.att(object, 'key', Properties.string),
        name = ObjectScheme.att(object, 'name', Properties.string),
        lessonsCount = ObjectScheme.att(object, 'lessonsCount', Properties.integer),
        days = ObjectScheme.att(object, 'days', Properties.boolMap),
        lessons = ObjectScheme.att(object, 'lessons', Properties.lessonsList),
        super(object);
}

class Lessons {
  final int index;
  final String from;
  final String to;
  final Map<String, String> lessons;

  Lessons(dynamic doc)
      : index = doc['index'],
        from = doc['from'],
        to = doc['to'],
        lessons = _stringMap(doc['lessons']);

  Map<String, dynamic> toMap() {
    return {'index': index, 'from': from, 'to': to, 'lessons': lessons};
  }
}
