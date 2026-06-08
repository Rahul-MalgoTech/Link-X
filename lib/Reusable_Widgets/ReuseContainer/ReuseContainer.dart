import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ReuseContainer extends StatelessWidget {
  final double? height; // used for container height
  final double? width; // used for container width
  final Color? color; // used for container color
  final Decoration? decoration; // add decoration to the container
  final Alignment? align; // used for allignment
  final Widget? child; //return widget
  final double? padding; // space around the container
  final double? margin; // space around the container
  final BoxConstraints? constraints; //set boc=xconstaints
  final int? seconds; //set seconds
  const ReuseContainer(
      {Key? key,
      this.color,
      this.child,
      this.width,
      this.height = 3.0,
      this.decoration,
      this.padding,
      this.margin,
      this.align,
      this.seconds = 0,
      this.constraints})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: seconds ?? 0),
      curve: Curves.easeOut,
      alignment: align,
      constraints: constraints,
      margin: EdgeInsets.all(margin ?? 0),
      height: height,
      width: width,
      padding: EdgeInsets.all(padding ?? 0),
      color: color,
      decoration: decoration,
      child: child,
    );
  }
}
