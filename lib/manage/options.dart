import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/subjects/courses/course_manage.dart';
import 'package:hephaistos/subjects/subject_manage.dart';
import 'package:hephaistos/timetable/timetable_manage.dart';

class OptionItem {
  final String title;
  final String desc;
  final WidgetBuilder builder;

  OptionItem(this.title, this.desc, this.builder);
}

class OptionsPage extends StatefulWidget {
  final String title;

  const OptionsPage({Key key, this.title}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  List<OptionItem> allOptions;

  @override
  void initState() {
    allOptions = [
      OptionItem('Subjects', 'All Subjects of you Group', (context) => SubjectListPage(title: 'Subjects')),
      OptionItem('Courses', 'All Courses of you Group', (context) => CourseListPage(title: 'Courses')),
      OptionItem('Timetables', 'All Timetables of you Group', (context) => TimetableListPage(title: 'Timetables'))
      //OptionItem('Courses', (context)=>SubjectListPage(title: 'Subjects'))
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: new ListView(
            children: ListTile.divideTiles(
          context: context,
          tiles: allOptions
              .map((item) => new ListTile(
                  title: Text(item.title), subtitle: Text(item.desc), onTap: () => Navigator.push(context, MaterialPageRoute(builder: item.builder))))
              .toList(),
        ).toList()));
  }
}
