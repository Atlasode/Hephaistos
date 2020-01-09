import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/data/cache.dart';
import 'package:hephaistos/data/data.dart';
import 'package:hephaistos/timetable/timetable.dart';

class TimetableListPage extends StatefulWidget {
  const TimetableListPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  State<StatefulWidget> createState() => _TimetableListPageState();
}

class _TimetableListPageState extends State<TimetableListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: CachedQuery(
          collection: Caches.groupCollection(GroupCache.timetables),
          builder: (context, cache) {
            List<Timetable> managers = cache.asList(GroupCache.timetables);
            return ListView(
                children: managers
                    .map((timetable) => Card(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ListTile(
                                title: Text(timetable.name.get()),
                                subtitle: Text('Lesson Count: ${timetable.lessonsCount.get()}'),
                              ),
                              Wrap(
                                spacing: 5,
                                children: Day.values
                                    .where((value) => timetable.days.get()[value.name])
                                    .map((value) => Chip(
                                          label: Text(value.short()),
                                        ))
                                    .toList(),
                              ),
                              ButtonBar(
                                alignment: MainAxisAlignment.start,
                                children: <Widget>[
                                  FlatButton(
                                    child: const Text('Delete'),
                                    onPressed: () => showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text('Delete Timetable'),
                                            actions: <Widget>[
                                              FlatButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
                                              FlatButton(
                                                  child: Text('Delete'),
                                                  onPressed: () {
                                                    Writer.start((writer) async {
                                                      writer.delete(Caches.groupDocument(key: GroupCache.timetables, path: timetable.key.get()));
                                                    }).then((_)=>Navigator.pop(context));
                                                  })
                                            ],
                                          );
                                        }),
                                  ),
                                  FlatButton(
                                    child: const Text('Edit Structure'),
                                    onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => TimetableCreationPage(
                                                title: 'Edit Structure',
                                                edit: true,
                                                name: timetable.name.get(),
                                                lessonsCount: timetable.lessonsCount.get(),
                                                id: timetable.key.get(),
                                                dayStates: Day.values.map((value) => timetable.days.get()[value.name]).toList()))),
                                  ),
                                  FlatButton(
                                      child: const Text('Select'),
                                      onPressed: () => showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: Text('Select Timetable'),
                                              actions: <Widget>[
                                                FlatButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
                                                FlatButton(
                                                    child: Text('Select'),
                                                    onPressed: () {
                                                      Writer.start((writer) async {
                                                        writer.update(Caches.userDocument(), (data) {
                                                          data
                                                              .as<User>(Caches.users)
                                                              .timetable
                                                              .set(timetable.key.get());
                                                          return data;
                                                        });
                                                      });
                                                      Navigator.pop(context);
                                                      Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (context) => TimetablePage(
                                                                title: timetable.name.get(),
                                                                timetableKey: timetable.key.get(),
                                                              )));
                                                    })
                                              ],
                                            );
                                          })),
                                ],
                              ),
                            ],
                          ),
                        ))
                    .toList());
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TimetableCreationPage(title: 'Create Timetable'))),
          tooltip: 'Create Timetable',
          child: Icon(Icons.add),
        ));
  }
}

class TimetableCreationPage extends StatefulWidget {
  const TimetableCreationPage(
      {Key key,
      this.title,
      this.edit = false,
      this.name,
      this.id,
      this.lessonsCount = 8,
      this.dayStates = const [true, true, true, true, true, false, false]})
      : super(key: key);

  final String title;
  final bool edit;
  final String name;
  final String id;
  final int lessonsCount;
  final List<bool> dayStates;

  @override
  State<StatefulWidget> createState() => _TimetableCreationPageState();
}

class _TimetableCreationPageState extends State<TimetableCreationPage> {
  TextEditingController nameInput;
  List<bool> dayStates;
  int lessonsCount;
  String id;

  final _formKey = GlobalKey<FormState>();

  @override
  initState() {
    nameInput = new TextEditingController(text: widget.name);
    if (widget.id == null) {
      id = Firestore.instance.collection('timetables').document().documentID;
    } else {
      id = widget.id;
    }
    dayStates = List.of(widget.dayStates);
    lessonsCount = widget.lessonsCount;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = <Widget>[
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
      Text('Lessons per Day', style: Theme.of(context).textTheme.subhead),
      Slider(
        min: 4,
        max: 16,
        label: '$lessonsCount Hours',
        value: lessonsCount.toDouble(),
        divisions: 12,
        onChanged: (double value) {
          setState(() {
            lessonsCount = value.floor();
          });
        },
      ),
      Text('Days', style: Theme.of(context).textTheme.subhead),
    ];
    Day.values.map((day) {
      String caption = day.name;
      return CheckboxListTile(
        title: Text('${caption[0].toUpperCase()}${caption.substring(1)}'),
        activeColor: Colors.green,
        value: dayStates[day.index],
        onChanged: (value) {
          setState(() {
            dayStates[day.index] = value;
          });
        },
      );
    }).forEach(children.add);
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
            children: children,
          ))),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_formKey.currentState.validate()) {
            String name = nameInput.text;
              Writer.start((writer) async {
                await writer.updateOrCreate(Caches.groupDocument(key: GroupCache.timetables, path: id), (data) {
                  Timetable timetable = data.as(GroupCache.timetables);
                  timetable.name.set(name);
                  timetable.lessonsCount.set(lessonsCount);
                  timetable.days.set(dayStates.asMap().map((index, value) => MapEntry(Day.values[index].name, value)));
                  timetable.key.set(data.document.documentID);
                  return data;
                }, update: widget.edit);
              }).then((_)=>Navigator.pop(context));
          }
        },
        child: Icon(Icons.check),
        tooltip: 'Done',
      ),
    );
  }
}
