import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FlutterUtils {
  static MaterialLocalizations localization(BuildContext context) => Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);

  static Map<String, List<String>> _shortWeekdays = {};
  static Map<String, List<String>> _weekdays = {};

  static String weekday(BuildContext context, int index) {
    Locale locale = Localizations.localeOf(context);
    return _weekdays.putIfAbsent(locale.toString(), () {
      DateFormat format = DateFormat.EEEE(locale.toString());
      return List.generate(7, (index) => format.format(DateTime.utc(1970, 1, 5 + index)));
    })[index];
  }

  static String shortWeekday(BuildContext context, int index) {
    Locale locale = Localizations.localeOf(context);
    return _shortWeekdays.putIfAbsent(locale.toString(), () {
      DateFormat format = DateFormat.E(locale.toString());
      return List.generate(7, (index) => format.format(DateTime.utc(1970, 1, 5 + index)));
    })[index];
  }
}
