
import 'package:bossy/Reusable_Widgets/AppText_Theme/AppText_Theme.dart';
import 'package:bossy/Reusable_Widgets/ReuseContainer/ReuseContainer.dart';
import 'package:flutter/material.dart';


class ReuseElevatedButton extends StatelessWidget {
  final String text;
  final double? width;
  final double? height;
  final FontWeight? fontWeight;
  final VoidCallback? onTap;
  final double? borderWidth;
  final TextStyle? style;
  final Color? buttonColor;
  final Color? textcolor;
  final double? fontSize;
  final BorderRadiusGeometry? borderRadius;
  final List<Color>? gradientColors;
  final Icon? icon;

  const ReuseElevatedButton({
    super.key,
    required this.text,
    this.width,
    this.height,
    this.onTap,
    this.fontWeight,
    this.borderRadius,
    this.borderWidth,
    this.textcolor,
    this.style,
    this.buttonColor,
    this.fontSize,
    this.gradientColors,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ReuseContainer(
        height: height ?? 55,
        width: width ?? MediaQuery.of(context).size.width * 0.85,
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(4),
          border: Border.all(
            color: Theme.of(context).canvasColor,
            width: borderWidth ?? 0,
          ),

          /// 🔥 APPLY GRADIENT IF PROVIDED
          gradient: gradientColors != null
              ? LinearGradient(
                  colors: gradientColors!,
                  begin: Alignment.centerLeft, // Horizontal START
                  end: Alignment.centerRight,
                )
              : null,

          /// 🔥 IF NO GRADIENT → FALLBACK COLOR
          color: gradientColors == null ? buttonColor ?? Colors.white : null,

          // boxShadow: [
          //   BoxShadow(
          //     offset: const Offset(0, 0),
          //     blurRadius: 0.3,
          //     spreadRadius: 0.5,
          //     color: Theme.of(context).dividerColor,
          //   ),
          // ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppText(
                text,
                color: textcolor ?? Colors.white,
                fontSize: fontSize ?? 17,
                fontWeight: FontWeight.w600,
              ),
              SizedBox(width: 10),
              icon ?? SizedBox(),
            ],
          ),
        ),
      ),
    );
  }
}

class ReuseElevatedBorderButton extends StatelessWidget {
  final String text;
  final double? width;
  final double? height;
  final FontWeight? fontWeight;
  final VoidCallback? onTap;
  final double? borderWidth;
  final TextStyle? style;
  final Color? buttonColor;
  final double? fontSize;
  final BorderRadiusGeometry? borderRadius;

  /// border gradient
  final List<Color>? gradientColors;

  /// text gradient
  final List<Color>? textGradientColors;

  const ReuseElevatedBorderButton({
    super.key,
    required this.text,
    this.width,
    this.height,
    this.onTap,
    this.fontWeight,
    this.borderRadius,
    this.borderWidth,
    this.style,
    this.buttonColor,
    this.fontSize,
    this.gradientColors,
    this.textGradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height ?? 55,
        width: width ?? MediaQuery.of(context).size.width * 0.85,

        // OUTER BORDER GRADIENT
        decoration: BoxDecoration(
          gradient: gradientColors != null
              ? LinearGradient(
                  colors: gradientColors!,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          borderRadius: borderRadius ?? BorderRadius.circular(6),
        ),

        child: Padding(
          padding: EdgeInsets.all(borderWidth ?? 2),

          // INNER CONTAINER
          child: Container(
            decoration: BoxDecoration(
              color: buttonColor ?? Colors.transparent,
              borderRadius: borderRadius ?? BorderRadius.circular(6),
            ),
            child: Center(
              child: textGradientColors != null
                  ? ShaderMask(
                      shaderCallback: (bounds) {
                        return LinearGradient(
                          colors: textGradientColors!,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        );
                      },
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        text,
                        style:
                            style ??
                            TextStyle(
                              fontSize: fontSize ?? 17,
                              fontWeight: fontWeight ?? FontWeight.w600,
                              color: Colors.white,
                            ),
                      ),
                    )
                  : Text(
                      text,
                      style:
                          style ??
                          TextStyle(
                            fontSize: fontSize ?? 17,
                            fontWeight: fontWeight ?? FontWeight.w600,
                            color: Colors.white,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
