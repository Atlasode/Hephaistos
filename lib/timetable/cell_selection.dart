import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/timetable/timetable.dart';
import 'package:hephaistos/widgets/color_picker.dart';

class CellSelectionPage extends StatefulWidget {
  final List<String> courses;
  final String title;

  const CellSelectionPage({Key key, this.title, this.courses = const []}) : super(key: key);

  @override
  State<CellSelectionPage> createState() => _CellSelectionPageState();
}

class _CellSelectionPageState extends State<CellSelectionPage> {
  _CellViewState cellView;
  ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    // full screen width and height
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    // height without SafeArea
    var padding = MediaQuery.of(context).padding;
    double height1 = height - padding.top - padding.bottom;

    // height without status bar
    double height2 = height - padding.top;

    // height without status and toolbar
    double height3 = height - padding.top - kToolbarHeight;
    return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: new Column(
          children: <Widget>[
            Container(
              width: width,
              height: height3 * 0.375,
              margin: EdgeInsets.symmetric(vertical: height3 * 0.02, horizontal: width * 0.05),
              child: Card(child: CellView(courses: widget.courses, stateUpdater: (value) => cellView = value)),
            ),
            Container(
                width: width,
                height: height3 * 0.45,
                margin: EdgeInsets.symmetric(horizontal: width * 0.05),
                child: Card(
                  child: CachedQuery(
                    collection: Caches.groupCollection(GroupCache.subjects),
                    builder: (context, subjectsCache) {
                      List<Subject> cacheList = subjectsCache.asList(GroupCache.subjects);
                      return new ListView(
                          controller: scrollController,
                          children: ListTile.divideTiles(
                              context: context,
                              tiles: cacheList.map((subject) {
                                return FilteredGroupCollection(
                                    collection: GroupCache.courses,
                                    schemeDocumentId: subject.object.document.documentID,
                                    scheme: subject,
                                    keyGetter: (subject) => subject.courses.get(),
                                    useBuilderForWaiting: true,
                                    builder: (context, coursesCache) {
                                      List<Course> courseList = coursesCache.asList(GroupCache.courses);
                                      return ExpansionTile(
                                        key: ValueKey(subject.key.get()),
                                        title: Text(subject.name.get(), style: TextStyle(color: subject.color.get())),
                                        subtitle: Text(subject.short.get()),
                                        children: ListTile.divideTiles(
                                            context: context,
                                            tiles: courseList.map((course) => CourseTile(
                                                course: course,
                                                onSelection: (value, state) => cellView.onSelection(value, state),
                                                selectionSupplier: () => cellView.courses.contains(course.key.get())))).toList(),
                                      );
                                    });
                              })).toList());
                    },
                  ),
                )),
            Container(
                margin: EdgeInsets.symmetric(horizontal: width * 0.05),
                child: ButtonBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    OutlineButton(
                      child: Text('Cencel'),
                        onPressed: () => Navigator.pop(context)
                    ),
                    OutlineButton(
                      child: Text('Submit'),
                      onPressed: () {
                        List<String> courses = cellView.courses;
                      },
                    )
                  ],
                ))
          ],
        ));
  }
}

class CourseTile extends StatefulWidget {
  final Course course;
  final Supplier<bool> selectionSupplier;
  final SelectionHandler<String> onSelection;

  const CourseTile({Key key, this.course, this.onSelection, this.selectionSupplier}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CourseTile();
}

class _CourseTile extends State<CourseTile> {
  bool selected;

  @override
  void initState() {
    super.initState();
    selected = widget.selectionSupplier();
  }

  @override
  Widget build(BuildContext context) {
    Course course = widget.course;
    return new ListTile(
        key: ValueKey(course.key.get()),
        onTap: () {
          setState(() {
            selected = widget.onSelection(course.key.get(), !selected) ? !selected : selected;
          });
        },
        title: Text(course.name.get()),
        subtitle: Text(course.short.get()),
        trailing: CircleColor(color: course.color.get(), circleSize: 42, isSelected: selected, iconSelected: Icons.check));
  }
}

class CellView extends StatefulWidget {
  final List<String> courses;
  final Consumer<_CellViewState> stateUpdater;

  const CellView({Key key, this.courses, this.stateUpdater}) : super(key: key);

  @override
  State<CellView> createState() => _CellViewState();
}

class _CellViewState extends State<CellView> {
  List<String> courses;

  @override
  void initState() {
    super.initState();
    this.courses = List.of(widget.courses);
    widget.stateUpdater(this);
  }

  bool onSelection(String value, bool state) {
    if (!state && courses.contains(value)) {
      setState(() {
        courses.remove(value);
      });
      return true;
    } else if (state && courses.length < 4) {
      setState(() {
        courses.add(value);
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: EdgeInsets.all(10),
        child: FilteredCollection(
            filterKey: 'cellSelection',
            keyGetter: (_) => List.of(courses),
            collection: GroupCache.courses,
            builder: (context, obj) {
              Map<String, List<Course>> coursesBySubject = {};
              List<Course> courses = obj.asList(GroupCache.courses);
              courses.forEach((course) {
                coursesBySubject.putIfAbsent(course.subjectKey.get(), () => []).add(course);
              });
              return FilteredCollection(
                  filterKey: 'cellSelectionSubjects',
                  keyGetter: (_) => List.of(coursesBySubject.keys),
                  collection: GroupCache.subjects,
                  builder: (context, obj) {
                    List<Subject> subjects = obj.asList(GroupCache.subjects);
                    List<Widget> widgets;
                    if (subjects.isNotEmpty) {
                      widgets = subjects
                          .map((subject) => coursesBySubject[subject.key.get()].map((course) => _buildCourse(subject, course)))
                          .expand((pair) => pair)
                          .toList();
                    } else {
                      widgets = [
                        const Card(
                          child: const Center(child: const Text('No Course is selected')),
                        )
                      ];
                    }
                    return ListView(
                      children: widgets,
                    );
                  });
            }));
  }

  Widget _buildCourse(Subject subject, Course course) {
    return Card(
        color: subject.color.get().withAlpha(135),
        child: Column(
          children: <Widget>[
            Center(
              child: Text(subject.name.get()),
            ),
            ListTile(
              title: Text(course != null ? course.name.get() : ''),
              subtitle: Text(course != null ? course.short.get() : ''),
              trailing: CircleColor(color: course.color.get(), circleSize: 42),
            )
          ],
        ));
  }
}
