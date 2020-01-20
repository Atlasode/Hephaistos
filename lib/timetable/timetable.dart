import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/subjects/courses/course_user.dart';
import 'package:hephaistos/timetable/cell_selection.dart';
import 'package:hephaistos/timetable/timetable_manage.dart';
import 'package:hephaistos/utils/flutter_utils.dart';

typedef SelectionHandler<V> = bool Function(V value, bool state);
typedef Supplier<T> = T Function();
typedef Consumer<T> = void Function(T value);

class TimetableMainPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CachedDocument(
      document: Caches.userDocument(),
      builder: (context, cache) {
        User user = cache.asScheme(Caches.users);
        if (user.timetable.get() != null && user.timetable.get().length > 0) {
          return TimetablePage(title: 'Timetable', timetableKey: user.timetable.get());
        }
        return TimetableListPage(title: 'Timetable');
      },
    );
  }
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({Key key, this.title, this.timetableKey}) : super(key: key);

  final String title;
  final String timetableKey;

  @override
  State<StatefulWidget> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  int selectedRow;
  int selectedIndex;

  TableRow _buildRow(BuildContext context, int rowIndex, Timetable timetable, [Lessons lessons]) {
    assert(rowIndex >= 0 && lessons != null || rowIndex == -1 && lessons == null);
    List<Widget> widgets = [];
    int cellIndex = 0;
    //The row with the negative index is the row that contains the names of the days
    if (rowIndex == -1) {
      widgets.add(buildCell(context, text: '', height: 40, row: -1, index: -1));
      Map<String, bool> days = timetable.days.get();
      List<String> dayNames = Day.values.where((day) => days[day.name]).map((day) => FlutterUtils.shortWeekday(context, day.index)).toList();
      widgets.addAll(dayNames.map((dayName) => buildCell(context, text: dayName, height: 40, row: rowIndex, index: cellIndex++)));
    } else {
      List<MapEntry<String, List<String>>> lessonList = lessons.courses.entries.toList();
      if (lessonList.isEmpty) {
        Map<String, bool> days = timetable.days.get();
        lessonList.addAll(Day.values.where((day) => days[day.name]).map((day) => MapEntry(day.name, [])));
      } else {
        lessonList.sort((a, b) => dayByName(a.key).index - dayByName(b.key).index);
      }
      widgets.add(buildCell(context, text: '${rowIndex + 1}.', row: rowIndex, index: -1));
      widgets.addAll(lessonList.map((entry) => buildCell(context, courses: entry.value, row: rowIndex, index: cellIndex++)));
    }
    return TableRow(children: widgets);
  }

  Widget _buildSubject(BuildContext context, Subject subject) {
    return new ListTile(
        title: Text(subject.name.get(), style: TextStyle(color: subject.color.get())),
        subtitle: Text(subject.short.get()),
        onTap: () {
          Writer.start((writer) async {
            await writer.updateOrCreate(Caches.groupDocument(key: GroupCache.timetables, path: widget.timetableKey), (data) {
              Timetable timetable = data.as(GroupCache.timetables);
              Iterable<Lessons> lessonsFilter = timetable.lessons.get().where((row) => row.index == selectedRow);
              if (lessonsFilter.isNotEmpty) {
                Lessons lessons = lessonsFilter.first;
                var days = timetable.days.get();
                List<Day> dayList = Day.values.where((day) => days[day.name]).toList();
                lessons.lessons[dayList[selectedIndex].name] = subject.key.get();
              } else {
                //TODO: Only happens if there is a bug in the system
              }
              timetable.lessons.forceUpdate();
              return data;
            }, update: true);
          }).then((_) => Navigator.pop(context));
        });
  }

  Widget buildCell(BuildContext context, {double height = 60.0, String text, List<String> courses, String subjectKey, int row = -1, int index = -1}) {
    assert(courses != null || subjectKey != null || text != null);
    Color defaultColor = Theme.of(context).canvasColor;
    if (row % 2 == 0 && index % 2 == 1 || row % 2 == 1 && index % 2 == 0) {
      defaultColor = Colors.grey[200];
    }
    Widget child;
    if (courses != null && courses.length > 0) {
      child = FilteredCollection(
          filterKey: 'timetable_courses:$row=$index',
          keyGetter: (_) => List.of(courses),
          collection: GroupCache.courses,
          builder: (context, obj) {
            Map<String, List<Course>> coursesBySubject = {};
            List<Course> courses = obj.asList(GroupCache.courses);
            courses.forEach((course) {
              coursesBySubject.putIfAbsent(course.subjectKey.get(), () => []).add(course);
            });
            return FilteredCollection(
                filterKey: 'timetable_subjects:$row=$index',
                keyGetter: (_) => List.of(coursesBySubject.keys),
                collection: GroupCache.subjects,
                builder: (context, obj) {
                  List<Subject> subjects = obj.asList(GroupCache.subjects);
                  Course course = courses.first;
                  Subject subject = obj.asSchemeOrNull(GroupCache.subjects);
                  return InkWell(
                      child: Container(
                        color: course != null && course.color != null ? course.color.get().withAlpha(135) : Theme
                            .of(context)
                            .canvasColor,
                        height: height,
                        child: Center(
                          child: Text(
                            course != null && course.name.get() != null ? course.name.get() : '',
                            style: Theme
                                .of(context)
                                .textTheme
                                .subhead,
                          ),
                        ),
                      ),
                      onTap: _onCellPress(context, true, row, index));
                });
          });
    } else
    if (subjectKey != null) {
      child = CachedDocument(
          document: Caches.groupDocument(key: GroupCache.subjects, path: subjectKey),
          builder: (context, cache) {
            Subject subject = cache.asSchemeOrNull(GroupCache.subjects);
            return InkWell(
                child: Container(
                  color: subject != null && subject.color != null ? subject.color.get().withAlpha(135) : Theme.of(context).canvasColor,
                  height: height,
                  child: Center(
                    child: Text(
                      subject != null && subject.name.get() != null ? subject.name.get() : '',
                      style: Theme.of(context).textTheme.subhead,
                    ),
                  ),
                ),
                onTap: _onCellPress(context, true, row, index));
          });
    } else {
      child = InkWell(
          child: Container(
            height: height,
            child: Center(
              child: Text(
                text ?? '',
                style: Theme.of(context).textTheme.body1,
              ),
            ),
          ),
          onTap: _onCellPress(context, courses != null, row, index));
    }
    return Container(
      color: defaultColor,
      child: child,
    );
  }

  GestureTapCallback _onCellPress(BuildContext context, bool lesson, int row, int index) {
    if (!lesson) {
      return null;
    }
    return () {
      setState(() {
        selectedRow = row;
        selectedIndex = index;
      });
      /*openSubjectSelection(context);*/
      Navigator.push(context, MaterialPageRoute(builder: (context) => CellSelectionPage(title: 'Select Subject', courses: ['6ZpflWcCWLKumM7RzSAX'])));
    };
  }

  void openSubjectSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
          margin: EdgeInsets.all(10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              CachedQuery(
                collection: Caches.groupCollection(GroupCache.subjects),
                builder: (context, cache) {
                  List<Subject> days = cache.asList(GroupCache.subjects);
                  return Container(
                      height: 300,
                      child: new ListView(
                        children: days.map((subject) {
                          return _buildSubject(context, subject);
                        }).toList(),
                      ));
                },
              ),
              Align(
                  alignment: Alignment.bottomRight,
                  child: FlatButton(
                    color: Colors.blue[200],
                    child: Text('Remove'),
                    onPressed: () {
                      Writer.start((writer) async {
                        await writer.updateOrCreate(Caches.groupDocument(key: GroupCache.timetables, path: widget.timetableKey), (data) {
                          Timetable timetable = data.as(GroupCache.timetables);
                          Iterable<Lessons> lessonsFilter = timetable.lessons.get().where((row) => row.index == selectedRow);
                          if (lessonsFilter.isNotEmpty) {
                            Lessons lessons = lessonsFilter.first;
                            var days = timetable.days.get();
                            List<Day> dayList = Day.values.where((day) => days[day.name]).toList();
                            lessons.lessons[dayList[selectedIndex].name] = '';
                          } else {
                            //TODO: Only happens if there is a bug in the system
                          }
                          timetable.lessons.forceUpdate();
                          return data;
                        }, update: true);
                      }).then((_) => Navigator.pop(context));
                    },
                  ))
            ],
          )),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(15.0), topRight: Radius.circular(15.0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          // action button
          Stack(
            children: [
              IconButton(
                  icon: Icon(Icons.widgets),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CourseSelection(title: 'Select Your Courses')))),
              new Positioned(
                right: 8,
                top: 8,
                child: new Container(
                  padding: EdgeInsets.all(1),
                  decoration: new BoxDecoration(color: Colors.amberAccent, borderRadius: BorderRadius.circular(6), boxShadow: [
                    BoxShadow(
                      color: Colors.grey,
                      blurRadius: 10.0, // has the effect of softening the shadow
                      spreadRadius: 3.0, // has the effect of extending the shadow,
                    )
                  ]),
                  constraints: BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                ),
              )
            ],
          ),
          IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
              }),
          IconButton(
              icon: Icon(Icons.autorenew),
              onPressed: () {
                Caches.document.clear();
              }),
          //PopupMenuButton()
        ]),
        body: new SingleChildScrollView(
            child: CachedDocument(
                document: Caches.groupDocument(key: GroupCache.timetables, path: widget.timetableKey),
                builder: (context, cache) {
                  Timetable timetable = cache.asSchemeOrNull(GroupCache.timetables);
                  List<TableRow> rows = [
                    _buildRow(context, -1, timetable)
                  ];
                  if (timetable != null) {
                    List<Lessons> lessonsList = timetable.lessons.get();
                    int rowIndex = 0;
                    rows.addAll(lessonsList.map((lessons) => _buildRow(context, rowIndex++, timetable, lessons)));
                  }
                  return Table(
                    columnWidths: {0: FlexColumnWidth(1)},
                    defaultColumnWidth: FlexColumnWidth(2),
                    border: TableBorder.all(color: Colors.grey),
                    children: rows,
                  );
                })));
  }
}
