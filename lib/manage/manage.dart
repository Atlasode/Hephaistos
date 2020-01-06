import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';

enum ManageOption { edit, delete }

class GroupOptions<S extends Named, C extends Named> extends StatelessWidget {
  final String title;
  final String addText;

  ///Collection of all possible options
  final CollectionKey<C> collection;

  ///Collection of all possible options
  final CollectionKey<S> schemeCollection;

  ///Document that controls the valid options
  final Document parent;

  /// Function that returns all valid options
  final KeyGetter<S> keyGetter;

  /// Builder function for the edit page.
  final Widget Function(BuildContext context, Named data, Document doc) editPageBuilder;

  /// Action for pressing the button
  final void Function() onAddPress;

  const GroupOptions(
      {Key key, this.schemeCollection, this.collection, this.editPageBuilder, this.title, this.addText, this.onAddPress, this.parent, this.keyGetter})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return new CachedDocument(
      document: parent,
      builder: (context, cache) {
        return FilteredGroupCollection<S, C>(
            collection: collection,
            schemeDocumentId: cache.doc().documentID,
            scheme: cache.asSchemeOrNull(schemeCollection),
            keyGetter: (d)=> d == null ? EMPTY_STRING_LIST : keyGetter(d),
            builder: (context, cache) {
              List<C> options = cache.asList(collection);
              List<Widget> widgets = ListTile.divideTiles(context: context, tiles: options.map((option) => _buildNamed(context, option))).toList();
              if (widgets.length > 0) {
                widgets.add(Divider());
              }
              widgets.insert(0, Divider());
              widgets.add(Center(
                child: FlatButton(
                  onPressed: onAddPress,
                  color: Colors.blue[200],
                  child: Text(addText),
                ),
              ));
              return ExpansionTile(title: Text(title), children: widgets);
            });
      },
    );
  }

  Widget _buildNamed(BuildContext context, C data) {
    return new ListTile(
        title: Text(data.name.get(), style: TextStyle(color: data.color.get())),
        subtitle: Text(data.short.get()),
        trailing: PopupMenuButton<ManageOption>(
          onSelected: (ManageOption result) {
            switch (result) {
              case ManageOption.edit:
                {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => editPageBuilder(context, data, data.object.document)));
                  break;
                }
              case ManageOption.delete:
                {
                  //removeOption(collection, data.reference);
                  break;
                }
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<ManageOption>>[
            const PopupMenuItem<ManageOption>(
              value: ManageOption.edit,
              child: Text('Edit'),
            ),
            const PopupMenuItem<ManageOption>(
              value: ManageOption.delete,
              child: Text('Delete'),
            ),
          ],
        ));
  }
}
