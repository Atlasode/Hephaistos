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
    User user = Caches
        .userDocument()
        .dataCache
        .as(Caches.users);
    return FutureBuilder<List<Subject>>(
        future: user.getMissingSubjects(),
        builder: (context, data) {
          if (data.connectionState == ConnectionState.waiting) {
            return Center(child: const CircularProgressIndicator());
          }
          return DefaultTabController(
              length: 2,
              child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Unselected'),
              Tab(text: 'Selected')
            ],
          ),
        ),
        body: CachedQuery(
          collection: Caches.groupCollection(GroupCache.subjects),
          builder: (context, subjectsCache) {
            List<String> unselectedKeys = data.data.map((subject) => subject.key.get()).toList();
            List<Subject> subjects = subjectsCache.asList(GroupCache.subjects);
            Widget selected = SubjectsView(subjects: subjects.where((subject) => !unselectedKeys.contains(subject.key.get())));
            Widget unselected = SubjectsView(subjects: data.data, unselected: true);
            return TabBarView(
              children: <Widget>[
                unselected,
                selected
              ],
            );
          },
        )));
        });
  }
}

class SubjectsView extends StatefulWidget {
  final Iterable<Subject> subjects;
  final bool unselected;

  const SubjectsView({Key key, this.subjects, this.unselected = false}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SubjectsViewState();

}

class _SubjectsViewState extends State<SubjectsView> {
  List<Widget> widgets;

  @override
  void initState() {
    super.initState();
    int index = 0;
    widgets = widget.subjects.where((data) =>
    data.courses
        .get(fallback: EMPTY_STRING_LIST)
        .length > 0)
        .map<Widget>((subject) {
      return FilteredGroupCollection<Subject, Course>(
          collection: GroupCache.courses,
          schemeDocumentId: subject.object.doc.documentID,
          scheme: subject,
          keyGetter: (data) => data.courses.get(fallback: EMPTY_STRING_LIST),
          builder: (context, coursesObj) {
            List<Course> courses = coursesObj.asList(GroupCache.courses);
            return SubjectCard(subject: subject, courses: courses, listIndex: index++);
          });
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unselected) {
      return AnimatedList(
          initialItemCount: widgets.length,
          itemBuilder: (context, index, animation) {
            return widgets[index];
          });
    } else {
      return ListView(
          children: widgets
      );
    }
  }

}

class SubjectCard extends StatefulWidget {
  final Subject subject;
  final List<Course> courses;
  final int selectedIndex;
  final String selectedCourse;
  final int listIndex;

  const SubjectCard({Key key, this.subject, this.courses, this.selectedCourse, this.selectedIndex = -1, this.listIndex}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _SubjectCardState();

}

class _SubjectCardState extends State<SubjectCard> {
  int selectedIndex;

  @override
  void initState() {
    super.initState();
    int index = widget.selectedIndex;
    if (widget.selectedCourse != null && widget.selectedCourse.length > 0) {
      Map<int, Course> courseByIndex = Map.of(widget.courses.asMap());
      courseByIndex.removeWhere((index, value) => value.key.get() != widget.selectedCourse);
      index = courseByIndex.keys.first;
    }
    selectedIndex = index;
  }

  void _selectIndex(BuildContext context, int index) {
    setState(() {
      selectedIndex = index;
    });
    _SubjectsViewState parent = context.findAncestorStateOfType<_SubjectsViewState>();
    parent.setState(() {
      parent.widgets.removeAt(widget.listIndex);
    });
    AnimatedList.of(context).removeItem(widget.listIndex, (context, animation) {
      return SubjectCard(subject: widget.subject, courses: widget.courses, selectedIndex: index, listIndex: widget.listIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    Subject subject = widget.subject;
    int index = 0;
    List<Widget> courseWidgets = widget.courses.map<Widget>((course) {
      return CourseCard(title: course.name.get(), subtitle: course.short.get(), color: course.color.get(), index: index++);
    }).toList();
    if (!subject.mandatory.get()) {
      courseWidgets.add(
          CourseCard(title: 'No course', subtitle: 'Not attended', color: Theme
              .of(context)
              .textTheme
              .title
              .color, index: index++));
    }
    return Container(
        margin: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Card(
            color: subject.color.get().withAlpha(125),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              new Center(
                  child: new Column(children: [
                    new Text(subject.name.get(), style: Theme
                        .of(context)
                        .textTheme
                        .headline),
                    new Text(subject.short.get(fallback: ''), style: Theme
                        .of(context)
                        .textTheme
                        .subhead)
                  ])),
              Container(
                  margin: EdgeInsets.symmetric(horizontal: 40.0, vertical: 5.0),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: courseWidgets))
            ])));
  }
}

class CourseCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color color;
  final int index;

  const CourseCard({Key key, this.index, this.title, this.subtitle, this.color}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _CourseCardState();

}

class _CourseCardState extends State<CourseCard> {

  @override
  Widget build(BuildContext context) {
    _SubjectCardState parent = context.findAncestorStateOfType<_SubjectCardState>();
    return Card(
      child: ListTile(
        title: Text(widget.title, style: TextStyle(color: widget.color)),
        subtitle: Text(widget.subtitle),
        trailing: Center(
          child: Radio(
            value: widget.index,
            groupValue: parent.selectedIndex,
            onChanged: (value) {
              parent._selectIndex(context, widget.index);
            },
          ),
          widthFactor: 1.5,
        ),
      ),
      color: Colors.grey[100],
    );
  }

}
