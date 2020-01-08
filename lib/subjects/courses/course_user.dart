import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';

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
