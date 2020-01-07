import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/manage/manage.dart';
import 'package:hephaistos/manage/subjects.dart';
import 'package:hephaistos/utils/firestore_utils.dart';

enum WhyFarther { edit, delete }

class CourseListPage extends StatelessWidget {
  final String title;

  const CourseListPage({Key key, this.title}) : super(key: key);

  Widget _buildCourse(BuildContext context, Course course, Document doc) {
    return new ListTile(
        title: Text(course.name.get(), style: TextStyle(color: course.color.get())),
        subtitle: Text(course.short.get()),
        trailing: PopupMenuButton<ManageOption>(
          onSelected: (ManageOption result) {
            switch (result) {
              case ManageOption.edit:
                {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => CoursePage(
                                title: 'Edit Course',
                                edit: true,
                                short: course.short.get(),
                                name: course.name.get(),
                                documentID: doc.documentID,
                              )));
                  break;
                }
              case ManageOption.delete:
                {
                  Writer.start((writer) async {
                    writer.delete(Caches.groupDocument(key: GroupCache.courses, path: course.key.get()));
                    writer.update(Caches.groupDocument(key: GroupCache.subjects, path: course.subjectKey.get()), (subjectData) {
                      Subject subject = subjectData.as(GroupCache.subjects);
                      List<String> courses = List.of(subject.courses.get(fallback: EMPTY_STRING_LIST));
                      if (courses.length > 0) {
                        courses.remove(course.key.get());
                      }
                      subject.courses.set(courses, forceUpdate: true);
                      return subjectData;
                    });
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
          builder: (context, subjectsCache) {
            List<Subject> cacheList = subjectsCache.asList(GroupCache.subjects);
            return new ListView(
                children: ListTile.divideTiles(
                    context: context,
                    tiles: cacheList.map((subject) {
                      return FilteredGroupCollection(
                          collection: GroupCache.courses,
                          schemeDocumentId: subject.object.document.documentID,
                          scheme: subject,
                          keyGetter: (subject) => subject.courses.get(),
                          builder: (context, coursesCache) {
                            List<Course> courseList = coursesCache.asList(GroupCache.courses);
                            return ExpansionTile(
                              title: Text(subject.name.get(), style: TextStyle(color: subject.color.get())),
                              subtitle: Text(subject.short.get()),
                              children: ListTile.divideTiles(
                                  context: context,
                                  tiles: courseList.map((course) {
                                    return _buildCourse(context, course, course.object.document);
                                  })).toList(),
                            );
                          });
                    })).toList());
          },
        ));
  }
}

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

class CourseSelection extends StatefulWidget {
  final String title;

  const CourseSelection({Key key, this.title}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CourseSelectionState();
}

class _CourseSelectionState extends State<CourseSelection> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: CachedQuery(
          collection: Caches.groupCollection(GroupCache.subjects),
          builder: (context, subjectsCache) {
            List<Subject> cacheList = subjectsCache.asList(GroupCache.subjects);
            List<Widget> widgets = cacheList.where((data) => data.courses.get(fallback: EMPTY_STRING_LIST).length > 0).map<Widget>((data) {
              Subject subject = data;
              return FilteredGroupCollection<Subject, Course>(
                  collection: GroupCache.courses,
                  schemeDocumentId: subject.object.doc.documentID,
                  scheme: subject,
                  keyGetter: (data) => data.courses.get(fallback: EMPTY_STRING_LIST),
                  builder: (context, coursesCache) {
                    List<Course> courseList = coursesCache.asList(GroupCache.courses);
                    return Container(
                        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                        child: Card(
                            color: subject.color.get().withAlpha(125),
                            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                              new Center(
                                  child: new Column(children: [
                                new Text(subject.name.get(), style: Theme.of(context).textTheme.headline),
                                new Text(subject.short.get(fallback: ''), style: Theme.of(context).textTheme.subhead)
                              ])),
                              /* ListTile(
                                title: Text(subject.name.get(), style: Theme.of(context).textTheme.headline.copyWith(color: subject.color.get())),
                                subtitle: Text(
                                  subject.short.get(),
                                ),
                                //subtitle: Text('Subject: ${course.subjectKey}'),
                              ),*/
                              Container(
                                  margin: EdgeInsets.symmetric(horizontal: 40.0, vertical: 5.0),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: courseList.map((course) {
                                        return Card(
                                          child: ListTile(
                                            title: Text(course.name.get(), style: TextStyle(color: course.color.get())),
                                            subtitle: Text(course.short.get()),
                                            trailing: Center(
                                              child: Icon(Icons.check_box_outline_blank),
                                              widthFactor: 1.5,
                                            ),
                                            //subtitle: Text('Subject: ${course.subjectKey}'),
                                          ),
                                          color: Colors.grey[100],
                                        );
                                      }).toList()))
                            ])));
                  });
            }).toList();
            widgets.insert(0, Center(child: Text('Selected Courses', style: Theme.of(context).textTheme.display1)));
            return new ListView(children: widgets);
          },
        ));
  }
}
