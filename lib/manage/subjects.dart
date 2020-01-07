import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/manage/course.dart';
import 'package:hephaistos/manage/manage.dart';
import 'package:hephaistos/utils/firestore_utils.dart';
import 'package:hephaistos/widgets/color_picker.dart';

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
                              color: data.color.get())));
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

class SubjectPage extends StatefulWidget {
  const SubjectPage({Key key, this.title, this.edit = false, this.name, this.short, this.id, this.mandatory = false, this.color = defaultColor})
      : super(key: key);

  final String title;
  final bool edit;
  final String name;
  final String short;
  final String id;
  final Color color;
  final bool mandatory;

  @override
  State<StatefulWidget> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  TextEditingController nameInput;
  TextEditingController shortInput;
  bool _mandatory = false;
  Color color;
  String id;

  final _formKey = GlobalKey<FormState>();

  @override
  initState() {
    nameInput = new TextEditingController(text: widget.name);
    shortInput = new TextEditingController(text: widget.short);
    if (widget.id == null) {
      id = FirestoreUtils.generateId();
    } else {
      id = widget.id;
    }
    _mandatory = widget.mandatory;
    color = widget.color;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Form(
          key: _formKey,
          child: SingleChildScrollView(
              child: Column(
            children: <Widget>[
              TextFormField(
                decoration: InputDecoration(labelText: 'Name*'),
                controller: nameInput,
                validator: (value) {
                  if (value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Short'),
                controller: shortInput,
              ),
              ListTile(
                title: Text('Subject Color'),
                subtitle: Text('Color in the timetable.'),
                trailing: CircleColor(
                  color: this.color,
                  circleSize: 45,
                  onColorChoose: () => ColorPickerDialog.show(context,
                      title: 'Subject Color',
                      defaultColor: this.color,
                      onColorChange: (color) => setState(() {
                            this.color = color;
                          })),
                ),
              ),
              CheckboxListTile(
                title: Text("Mandatory"),
                activeColor: Colors.green,
                value: _mandatory,
                onChanged: (value) {
                  setState(() {
                    _mandatory = value;
                  });
                },
              ),
              GroupOptions<Subject, Course>(
                  schemeCollection: GroupCache.subjects,
                  collection: GroupCache.courses,
                  keyGetter: (data) => data.courses.get(fallback: EMPTY_STRING_LIST),
                  parent: Caches.groupDocument(key: GroupCache.subjects, path: id),
                  editPageBuilder: (context, doc, node) => CoursePage(
                      title: 'Edit Courses', name: doc.name.get(), short: doc.short.get(), edit: true, documentID: node.documentID, subjectKey: id),
                  title: 'Courses',
                  addText: 'Add Course',
                  onAddPress: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CoursePage(title: 'Create Course', edit: false, subjectKey: id)));
                  }),
            ],
          ))),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState.validate()) {
            String name = nameInput.text;
            String short = shortInput.text;
            Writer.start((writer) async {
              writer.updateOrCreate(Caches.groupDocument(key: GroupCache.subjects, path: id), (data) {
                Subject subject = data.as(GroupCache.subjects);
                subject.name.set(name);
                subject.short.set(short);
                subject.color.set(color);
                subject.key.set(data.document.documentID);
                subject.mandatory.set(_mandatory);
                return data;
              }, update: widget.edit);
            }).then((_) => Navigator.pop(context));
          }
        },
        child: Icon(Icons.check),
        tooltip: 'Done',
      ),
    );
  }
}
