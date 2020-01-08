import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/manage/manage.dart';
import 'package:hephaistos/subjects/subject.dart';
import 'package:hephaistos/utils/firestore_utils.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({Key key, this.title, this.name = '', this.short = '', this.subjectKey, this.edit = false, this.documentID}) : super(key: key);

  final String title;
  final String name;
  final String short;
  final String subjectKey;
  final bool edit;
  final String documentID;

  @override
  State<StatefulWidget> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  TextEditingController nameInput;
  TextEditingController shortInput;
  String id;

  final _formKey = GlobalKey<FormState>();

  @override
  initState() {
    nameInput = new TextEditingController(text: widget.name);
    shortInput = new TextEditingController(text: widget.short);
    if (widget.documentID == null) {
      id = FirestoreUtils.generateId();
    } else {
      id = widget.documentID;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              GroupOptions<Course, Named>(
                  schemeCollection: GroupCache.courses,
                  collection: GroupCache.persons,
                  keyGetter: (data) => data.persons.get(fallback: EMPTY_STRING_LIST),
                  parent: Caches.groupDocument(key: GroupCache.courses, path: id),
                  editPageBuilder: (context, data, doc) => SubjectPage(title: 'Edit Person'),
                  title: 'Persons',
                  addText: 'Add Person'),
              GroupOptions<Course, Room>(
                  schemeCollection: GroupCache.courses,
                  collection: GroupCache.rooms,
                  keyGetter: (data) => data.rooms.get(fallback: EMPTY_STRING_LIST),
                  parent: Caches.groupDocument(key: GroupCache.courses, path: id),
                  editPageBuilder: (context, data, doc) => SubjectPage(title: 'Edit Room'),
                  title: 'Rooms',
                  addText: 'Add Room')
            ],
          ))),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState.validate()) {
            String name = nameInput.text;
            String short = shortInput.text;
            Writer.start((writer) async {
              writer.updateOrCreate(Caches.groupDocument(key: GroupCache.courses, path: id), (data) {
                Course course = data.as(GroupCache.courses);
                course.name.set(name);
                course.short.set(short);
                course.color.set(Color(int.parse(defaultColorCode)));
                course.key.set(data.document.documentID);
                course.subjectKey.set(widget.subjectKey);
                return data;
              }, update: widget.edit);
              if (!widget.edit) {
                writer.update(Caches.groupDocument(key: GroupCache.subjects, path: widget.subjectKey), (data) {
                  Subject subject = data.as(GroupCache.subjects);
                  List<String> courses = List.of(subject.courses.get(fallback: <String>[]));
                  courses.add(id);
                  subject.courses.set(courses);
                  return data;
                });
              }
            }).then((_) => Navigator.pop(context));
          }
        },
        child: Icon(Icons.check),
        tooltip: 'Done',
      ),
    );
  }
}
