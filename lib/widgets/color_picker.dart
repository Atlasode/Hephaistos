import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/block_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_colorpicker/material_picker.dart';

class ColorPickerDialog extends StatefulWidget {
  final String title;
  final ValueChanged<Color> onColorChange;
  final Color defaultColor;

  const ColorPickerDialog({Key key, this.title, this.onColorChange, this.defaultColor}) : super(key: key);

  @override
  State<StatefulWidget> createState()=>_ColorPickerDialogState();

  static show(BuildContext context, { String title, ValueChanged<Color> onColorChange, Color defaultColor}) {
    showDialog(
        context: context,
        builder: (context) {
          return ColorPickerDialog(title: title, onColorChange: onColorChange, defaultColor: defaultColor);
        }
    );
  }

}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  Color color;

  @override
  void initState() {
    super.initState();
    color = widget.defaultColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content:  MaterialPicker(
        onColorChanged:(color){
          setState(() {
            this.color = color;
          });},
        pickerColor: widget.defaultColor,
        //enableLabel: true,
      ),
      actions: <Widget>[
        FlatButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context)),
        FlatButton(
            child: Text('Submit'),
            onPressed: () {
              widget.onColorChange(color);
              Navigator.pop(context);
            })
      ],
    );
  }

}

class CircleColor extends StatelessWidget {
  static const double _kColorElevation = 4.0;

  final bool isSelected;
  final Color color;
  final VoidCallback onColorChoose;
  final double circleSize;
  final double elevation;
  final IconData iconSelected;

  const CircleColor({
    Key key,
    @required this.color,
    @required this.circleSize,
    this.onColorChoose,
    this.isSelected = false,
    this.elevation = _kColorElevation,
    this.iconSelected,
  })  : assert(color != null, "You must provide a not null Color"),
        assert(circleSize != null, "CircleColor must have a not null size"),
        assert(circleSize >= 0, "You must provide a positive size"),
        assert(!isSelected || (isSelected && iconSelected != null)),
        super(key: key);

  @override
  Widget build(BuildContext context) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final icon = brightness == Brightness.light ? Colors.black : Colors.white;

    return GestureDetector(
      onTap: onColorChoose,
      child: Material(
        elevation: elevation ?? _kColorElevation,
        shape: const CircleBorder(),
        child: CircleAvatar(
          radius: circleSize / 2,
          backgroundColor: color,
          child: isSelected ? Icon(iconSelected, color: icon) : null,
        ),
      ),
    );
  }
}