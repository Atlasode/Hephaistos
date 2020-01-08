import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/manage/manage.dart';
import 'package:hephaistos/subjects/courses/course.dart';

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
