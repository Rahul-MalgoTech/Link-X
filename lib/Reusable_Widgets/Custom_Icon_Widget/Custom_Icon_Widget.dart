
import 'package:bossy/Bossy_Utils/App_Theme/App_Theme.dart';
import 'package:bossy/Bossy_Utils/Midea_Query/MediaQuery.dart';
import 'package:bossy/Reusable_Widgets/AppText_Theme/AppText_Theme.dart';
import 'package:flutter/material.dart';




class CustomIconTextWidget extends StatelessWidget {
  final IconData iconData;
  final String text;
  final Color? textColor;
  final double? fontSize;


  CustomIconTextWidget({
    required this.iconData,
    required this.text,
    this.textColor,
    this.fontSize,

  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: SizeConfig.height(context, 8),
      width: MediaQuery.sizeOf(context).width,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  iconData,
                  color: Theme.of(context).colorScheme.background,
                  size: 20,
                ),
                SizedBox(
                  width: SizeConfig.height(context, 2),
                ),
                AppText(
                  text,

                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.background,
                  fontSize: fontSize ?? 16,
                ),
              ],
            ),
// Switch for dark mode
            if (text.toLowerCase() == "dark mode")
              const ThemeToggleIcon(),

          ],
        ),
      ),
    );
  }
}
