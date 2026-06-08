import 'package:flutter/material.dart';

class bondNavigator {
  static newPage(BuildContext context, {required Widget page}) {
    Navigator.push(context, MaterialPageRoute(builder: (builder) => page));
  }

  static backPage(BuildContext context) {
    Navigator.pop(context);
  }

  static newPageRemoveUntil(BuildContext context, {required Widget page}) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (BuildContext context) => page),
      (route) => false,
    );
  }

  static replacePage(BuildContext context, {required Widget page}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => page),
    );
  }
}
