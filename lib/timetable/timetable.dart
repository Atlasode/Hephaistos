import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/constants.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/manage/course.dart';
import 'package:hephaistos/timetable/timetable_selection.dart';
import 'package:hephaistos/widgets/color_picker.dart';

typedef SelectionHandler<V> = bool Function(V value, bool state);
typedef Supplier<T> = T Function();
typedef Consumer<T> = void Function(T value);

class LessonRow {
  final int index;
  final RowType type;
  final Map<String, String> lessons;
  final String from;
  final String to;
  final bool dayRow;

  LessonRow(this.type, this.lessons, {this.index = -1, this.from = '', this.to = '', this.dayRow = false});

  TableRow buildTableRow(BuildContext context, _TimetablePageState state) {
    List<Widget> widgets = [];
    List<MapEntry<String, String>> lessonList = lessons.entries.toList();
    lessonList.sort((a, b) => dayByName(a.key).index - dayByName(b.key).index);
    if (!dayRow) {
      widgets.add(state.buildCell(context, '${this.index + 1}.', row: this.index, index: -1));
      int cellIndex = 0;
      widgets.addAll(lessonList.map((entry) => state.buildCell(context, entry.value, lesson: true, row: this.index, index: cellIndex++)));
    } else {
      widgets.add(state.buildCell(context, '', height: 40, row: -1, index: -1));
      int cellIndex = 0;
      widgets.addAll(lessonList.map(
          (entry) => state.buildCell(context, '${entry.key[0].toUpperCase()}${entry.key.substring(1, 3)}', height: 40, row: -1, index: cellIndex++)));
    }
    return TableRow(children: widgets);
  }
}

/// Currently not used, could be used for 'breaks'
enum RowType { DAY, LESSON, BREAK }

class TimetableManager {
  LessonRow dayRow;
  LinkedHashMap<int, LessonRow> rows;
  int lessonCount;
  String name;
  String key;
  Map<String, bool> days;

  TimetableManager(Timetable timetable) : rows = new LinkedHashMap() {
    var days = timetable.days.get();
    this.lessonCount = timetable.lessonsCount.get();
    this.name = timetable.name.get();
    this.key = timetable.key.get();
    List<Day> dayList;
    if (days != null) {
      dayList = Day.values.where((day) => days[day.name]).toList();
      this.days = Map.fromIterable(Day.values, key: (day) => day.name, value: (day) => days[day.name]);
    } else {
      // This only can be caused by a bug at the creation of the timetable, so we use the first five days
      //TODO: Fix document ?
      dayList = Day.values.getRange(0, 5).toList();
      this.days = defaultDays;
    }
    dayRow = new LessonRow(RowType.DAY, Map.fromIterable(dayList, key: (day) => day.name, value: (day) => ''), dayRow: true);
    if (timetable.lessons.get() != null && timetable.lessons.get().length > 0) {
      for (int i = 0; i < lessonCount; i++) {
        Lessons rowData = timetable.lessons.get()[i];
        Map<dynamic, dynamic> rowLessons = rowData.lessons;
        rows[i] = new LessonRow(RowType.LESSON,
            Map.fromIterable(dayList, key: (day) => day.name, value: (day) => rowLessons[day.name] != null ? rowLessons[day.name] : ''),
            index: i);
      }
    } else {
      for (int i = 0; i < lessonCount; i++) {
        rows[i] = new LessonRow(RowType.LESSON, Map.fromIterable(dayList, key: (day) => day.name, value: (day) => ''), index: i);
      }
    }
  }

  Task update(int row, int cell) {}
}

class Task {
  final TaskType type;

  Task(this.type);
}

enum TimetableState { EXISTING, UNKNOWN }

enum TaskType { CREATE_ROW, CREATE_ALL, UPDATE_CELL, CLEAN_UP }

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

  Widget buildCell(BuildContext context, String title, {double height = 60.0, bool lesson = false, int row = -1, int index = -1}) {
    Color defaultColor = Theme.of(context).canvasColor;
    if (row % 2 == 0 && index % 2 == 1 || row % 2 == 1 && index % 2 == 0) {
      defaultColor = Colors.grey[200];
    }
    Widget child;
    if (lesson && title.length > 0) {
      child = CachedDocument(
          document: Caches.groupDocument(key: GroupCache.subjects, path: title),
          customWaiting: (context, cache) {
            Subject subject = cache.asSchemeOrNull(GroupCache.subjects);
            return InkWell(
              child: Container(
                  color: subject != null && subject.color != null ? subject.color.get().withAlpha(135) : Theme.of(context).canvasColor,
                  height: height,
                  child: Center(child: new Text(subject != null && subject.name.get() != null ? subject.name.get() : ''))),
              onTap: _onCellPress(context, lesson, row, index, key: title),
            );
          },
          builder: (context, cache) {
            Subject subject = cache.asScheme(GroupCache.subjects);
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
                onTap: _onCellPress(context, lesson, row, index, key: title));
          });
    } else {
      child = InkWell(
          child: Container(
            height: height,
            child: Center(
              child: Text(
                title,
                style: Theme.of(context).textTheme.body1,
              ),
            ),
          ),
          onTap: _onCellPress(context, lesson, row, index));
    }
    return Container(
      color: defaultColor,
      child: child,
    );
  }

  GestureTapCallback _onCellPress(BuildContext context, bool lesson, int row, int index, {String key}) {
    if (!lesson) {
      return null;
    }
    return () {
      setState(() {
        selectedRow = row;
        selectedIndex = index;
      });
      /*openSubjectSelection(context);*/
      Navigator.push(context, MaterialPageRoute(builder: (context) => CellSelectionPage(title: 'Create Subject', courses: ['6ZpflWcCWLKumM7RzSAX'])));
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
                updateStore('courses');
                updateStore('subjects');
                updateStore('rooms');
                updateStore('timetables');
                updateStore('persons');
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
                  TimetableManager manager = TimetableManager(cache.asScheme(GroupCache.timetables));
                  List<LessonRow> rows = manager.rows.values.toList();
                  rows.insert(0, manager.dayRow);
                  return Table(
                    columnWidths: {0: FlexColumnWidth(1)},
                    defaultColumnWidth: FlexColumnWidth(2),
                    border: TableBorder.all(color: Colors.grey),
                    children: rows.map((row) => row.buildTableRow(context, this)).toList(),
                  );
                })));
  }

  void updateStore(String collections) {
    CollectionReference ref = Firestore.instance.collection(collections);
    ref.getDocuments().then((value) {
      value.documents.asMap().map((key, value) {
        return MapEntry(value.documentID, value.data);
      }).forEach((key, value) {
        Firestore.instance.collection('groups').document(debugGroup).collection(collections).document(key).setData(value);
      });
    });
  }
}

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
              height: height3 * 0.2,
              margin: EdgeInsets.symmetric(vertical: height3 * 0.05, horizontal: width * 0.075),
              child: Card(child: CellView(courses: widget.courses, stateUpdater: (value)=>cellView=value)),
            ),
            Container(
                width: width,
                height: height3 * 0.6,
                margin: EdgeInsets.symmetric(vertical: height3 * 0.05, horizontal: width * 0.05),
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
                                            tiles: courseList.map((course)=> CourseTile(course: course, onSelection: (value, state)=>cellView.onSelection(value, state)))).toList(),
                                      );
                                    });
                              })).toList());
                    },
                  ),
                )),
          ],
        ));
  }
}

class CourseTile extends StatefulWidget {
  final Course course;
  final SelectionHandler<String> onSelection;

  const CourseTile({Key key, this.course, this.onSelection}) : super(key: key);

  @override
  State<StatefulWidget> createState() =>_CourseTile();

}

class _CourseTile extends State<CourseTile> {
  bool selected;

  @override
  void initState() {
    super.initState();
    selected = false;
  }

  @override
  Widget build(BuildContext context) {
    Course course = widget.course;
    return new ListTile(
        key: ValueKey(course.key.get()),
        onTap: (){
          setState(() {
            selected=widget.onSelection(course.key.get(), !selected) ? !selected : selected;
          });
        },
        title: Text(course.name.get()),
        subtitle: Text(course.short.get()),
        trailing: CircleColor(color: course.color.get(), circleSize: 42, isSelected:selected, iconSelected: Icons.check));
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
  //Map<String, List<String>> coursesBySubject;

  @override
  void initState() {
    super.initState();
    this.courses = List.of(widget.courses);
    widget.stateUpdater(this);
    /*coursesBySubject= {};
    for(String course in courses) {
      Document doc = Caches.groupDocument(key: GroupCache.courses, path: course);
      doc.requestData().then((obj){
        Course course = obj.asSchemeOrNull(GroupCache.courses);
        if(course != null){
          setState(() {
            coursesBySubject.putIfAbsent(course.subjectKey.get(), ()=>[]).add(course.key.get());
          });
        }
      });
    }*/
  }

  bool onSelection(String value, bool state){
    if(!state && courses.contains(value)){
      setState(() {
        courses.remove(value);
      });
      return true;
    } else if(state && courses.length < 4) {
      setState(() {
        courses.add(value);
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets;
    if (courses.isNotEmpty) {
      widgets = courses.map(_buildCourse).toList();
    } else {
      widgets = [
        const Expanded(
            child: const Card(
          child: const Center(child: const Text('No Course is selected')),
        ))
      ];
    }
    return Container(
        margin: EdgeInsets.all(10),
        child:/* FilteredCollection(

    builder: (context, obj)=>*/Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    ));
  }

  Widget _buildCourse(String courseKey) {
    return Expanded(
      child: CachedDocument(
          document: Caches.groupDocument(key: GroupCache.courses, path: courseKey),
          builder: (context, cache) {
            Course course = cache.asScheme(GroupCache.courses);
            return CachedDocument(
              document: Caches.groupDocument(key: GroupCache.subjects, path: course.subjectKey.get()),
              builder: (context, cache) {
                Subject subject = cache.asScheme(GroupCache.subjects);
                return Card(
                    color: subject.color.get().withAlpha(135),
                    child: Column(
                      children: <Widget>[Text(course != null ? course.name.get() : '')],
                    ));
              }
            );
          }),
    );
  }
}
