import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/manage/manage.dart';
import 'package:hephaistos/subjects/subject.dart';

class SubjectListPage extends StatelessWidget {
  final String title;

  const SubjectListPage({Key key, this.title}) : super(key: key);

  Widget _buildSubject(BuildContext context, Subject data) {
    return new ListTile(
        title: Text(data.name.get(), style: TextStyle(color: data.color.get())),
        subtitle: Text(data.short.get()),
        trailing: PopupMenuButton<ManageOption>(
          onSelected: (ManageOption result) {
            switch (result) {
              case ManageOption.edit:
                {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SubjectPage(
                              title: 'Edit Subject',
                              edit: true,
                              short: data.short.get(),
                              name: data.name.get(),
                              id: data.key.get(),
                              mandatory: data.mandatory.get(),
                              color: data.color.get(),
                              coursed: data.coursed.get())));
                  break;
                }
              case ManageOption.delete:
                {
                  Writer.start((writer) async {
                    writer.delete(Caches.groupDocument(key: GroupCache.subjects, path: data.key.get()));
                  });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: CachedQuery(
        collection: Caches.groupCollection(GroupCache.subjects),
        builder: (context, cache) {
          List<Subject> subjects = cache.asList(GroupCache.subjects);
          return new ListView(
            children: ListTile.divideTiles(
                    context: context,
                    tiles: subjects.map((data) {
                      return _buildSubject(context, data);
                    }).toList())
                .toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectPage(title: 'Create Subject'))),
        tooltip: 'Create Subject',
        child: Icon(Icons.add),
      ),
    );
  }
}
