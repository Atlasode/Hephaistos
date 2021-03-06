import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hephaistos/data/data.dart';

final String defaultUser = 'H23tYYz0HVtttdBH7CNr';
final String debugGroup = 'r8Sg9xSohFgSBCrBb1Ql';
final String defaultColorCode = "0xFFF44336";
const Color defaultColor = Colors.red;
final int defaultLessonCount = 8;
final Map<String, bool> defaultDays = Day.values.asMap().map((index, day) {
  return new MapEntry(day.name, index < 5);
});
const List<String> EMPTY_STRING_LIST = const <String>[];
