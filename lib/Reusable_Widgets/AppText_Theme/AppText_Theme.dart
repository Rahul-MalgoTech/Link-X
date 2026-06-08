import 'package:flutter/material.dart';

class AppText extends StatefulWidget {
  final String data;
  FontWeight? fontWeight;
  double? fontSize;
  Color? color;
  final TextDecoration? decoration;
  final double? letterSpacing;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;

  AppText(
    @required this.data, {
    Key? key,
    this.fontWeight = FontWeight.normal,
    this.fontSize = 16,
    this.color,
    this.decoration,
    this.textAlign,
    this.style,
    this.overflow,
    this.letterSpacing,
        this.maxLines,
    String? fontFamily,
  }) : super(key: key);

  @override
  State<AppText> createState() => _AppTextState();
}

class _AppTextState extends State<AppText> {
  @override
  Widget build(BuildContext context) {
    return Text(
      widget.data,
      textAlign: widget.textAlign ?? TextAlign.left,
      style:
          widget.style ??
          TextStyle(
            decoration: widget.decoration,
            color: widget.color ?? Theme.of(context).colorScheme.surfaceBright,
            fontFamily: 'Manrope',
            fontSize: widget.fontSize,
            letterSpacing: widget.letterSpacing??-0.7,
            overflow: widget.overflow,
            fontWeight: widget.fontWeight,

          ),
      overflow: widget.overflow,
      maxLines: widget.maxLines,
    );
  }
}
