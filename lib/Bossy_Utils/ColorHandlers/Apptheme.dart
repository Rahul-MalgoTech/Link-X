import 'package:bossy/Bossy_Utils/ColorHandlers/AppColors.dart';
import 'package:flutter/material.dart';


class Apptheme {
  /// light theme Color
  static final lightThemeData = ThemeData(
    bottomAppBarTheme: BottomAppBarThemeData(
        color: Color(0xFFD4D4D4)), // Set bottom app bar color to gray
    colorScheme: ColorScheme.fromSwatch().copyWith(
      surfaceBright: appColors.bgTextLight, // Set your background color here
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appColors.appPrimaryColorLight,
    ),
    scaffoldBackgroundColor: appColors.appPrimaryColorLight,


    fontFamily: "LexendDeca",
    primaryColor: appColors.appPrimaryColorLight,
    primaryColorLight: appColors.appBodyColorLight1,
    primaryColorDark: appColors.appBodyColorLight2,
    iconTheme: IconThemeData(color:appColors.iconColorLight,),

    primarySwatch:
        MaterialColor(appColors.lightPrimaryColor, appColors.lightSwatchColor),
    cardColor: appColors.cardBackgroundLight,
    // backgroundColor: appColors.bgTextLight,
    shadowColor: Colors.white,
    hintColor: appColors.hintTextLight,
    highlightColor: Colors.white,
    unselectedWidgetColor: appColors.roundedButtonColorLight1,
    focusColor: appColors.roundedButtonColorLight2,
    // errorColor: appColors.errorSanckBarColorLight,
    canvasColor: appColors.greyContainerLight,
    dividerColor: appColors.buttonLightDiableGrey2,
    chipTheme: ChipThemeData(
      backgroundColor: appColors.SwapArrowRoundLight,
    ),
    indicatorColor: appColors.greyTextLight,
    disabledColor: appColors.hintLight,
    hoverColor: appColors.userTextLight,
    textTheme: TextTheme(
      labelLarge: TextStyle(
        color: appColors.textLight,
        fontFamily: "LexendDeca",
        fontSize: 18,
        fontWeight: FontWeight.w400,
      ),
      labelMedium: TextStyle(
          color: appColors.textLight,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold),
      labelSmall: TextStyle(
          color: appColors.textLight,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.normal),
      bodyLarge: TextStyle(
        color: appColors.textBlackColorLight,
        fontFamily: "LexendDeca",
        fontSize: 23,
        overflow: TextOverflow.ellipsis,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(
          color: appColors.textBlackColorLight,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold,
          overflow: TextOverflow.ellipsis),
      bodySmall: TextStyle(
          color: appColors.textBlackColorLight,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.normal,
          overflow: TextOverflow.ellipsis),
      displayLarge: TextStyle(
          color: appColors.textLight,
          fontFamily: "LexendDeca",
          fontSize: 23,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline),
      displayMedium: TextStyle(
          color: appColors.underlineTextLight,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline),
      displaySmall: TextStyle(
          color: appColors.underlineTextLight,
          fontFamily: "LexendDeca",
          fontSize: 14,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.normal),
      titleLarge: TextStyle(
          color: appColors.cntTextLight,
          fontFamily: "LexendDeca",
          fontSize: 23,
          fontWeight: FontWeight.w700),
      titleMedium: TextStyle(
          color: appColors.cntTextLight1,
          fontFamily: "LexendDeca",
          fontSize: 20,
          fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(
          color: appColors.cntTextLight1,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(
        color: appColors.cntTextLight,
        fontFamily: "BricolageGrotesque",
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: TextStyle(
        color: appColors.cntTextLight1,
        fontFamily: "BricolageGrotesque",
        fontSize: 30,
        fontWeight: FontWeight.w500,
      ),

    ),
    buttonTheme: ButtonThemeData(
      buttonColor: appColors.textBlackColorLight,
      focusColor: appColors.roundedButtonColorLight1,
      hoverColor: appColors.roundedButtonColorLight2,
    ),
    //iconTheme: IconThemeData(color: appColors.textBlackColorLight)
  );

  /// Dark Theme Color
  static final darkThemeData = ThemeData(
    appBarTheme: AppBarTheme(
      backgroundColor: appColors.appPrimartColorDark,
    ),
    colorScheme: ColorScheme.fromSwatch().copyWith(
        surfaceBright: appColors.bgTextDark, surface: appColors.bgTextDark),
    scaffoldBackgroundColor: appColors.appPrimartColorDark,
    fontFamily: "LexendDeca",
    primaryColor: appColors.appPrimartColorDark,
    iconTheme: IconThemeData(color:appColors.iconColorDark,),
    primaryColorLight: appColors.appBodyColorDark1,
    primaryColorDark: appColors.appBodyColorDark2,
    primarySwatch:
        MaterialColor(appColors.darkPrimaryColor, appColors.darkSwatchColor),
    cardColor: appColors.cardBackgroundDark,
    // backgroundColor: appColors.bgTextDark,
    hintColor: appColors.hintTextDark,
    shadowColor: Color(0xFF364153),
    canvasColor: appColors.greyContainerDark,
    unselectedWidgetColor: appColors.roundedButtonColorDark1,
    highlightColor: Color(0XFF515a6a),
    focusColor: appColors.roundedButtonColorDark2,
    // errorColor: appColors.errorSanckBarColorDark,
    dividerColor: appColors.buttonDiableGrey2,
    indicatorColor: appColors.greyTextDark,
    hoverColor: appColors.userTextDark,
    chipTheme: ChipThemeData(
      backgroundColor: appColors.SwapArrowRoundDark,
    ),
    disabledColor: appColors.hintdark,
    bottomAppBarTheme: BottomAppBarThemeData(
        color: Color(0xFF262737)), // Set bottom app bar color to black
    textTheme: TextTheme(
      labelLarge: TextStyle(
          color: appColors.textDark,
          fontFamily: "LexendDeca",
          fontSize: 18,
          fontWeight: FontWeight.w400),
      labelMedium: TextStyle(
          color: appColors.textDark,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold),
      labelSmall: TextStyle(
          color: appColors.textDark,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.normal),
      bodyLarge: TextStyle(
        color: appColors.textBlackColorDark,
        fontFamily: "LexendDeca",
        fontSize: 23,
        overflow: TextOverflow.ellipsis,
        fontWeight: FontWeight.bold,
      ),
      bodyMedium: TextStyle(
          color: appColors.textBlackColorDark,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold,
          overflow: TextOverflow.ellipsis),
      bodySmall: TextStyle(
        color: appColors.textBlackColorDark,
        fontFamily: "LexendDeca",
        fontSize: 14,
        fontWeight: FontWeight.normal,
        overflow: TextOverflow.ellipsis,
      ),
      displayLarge: TextStyle(
          color: appColors.textDark,
          fontFamily: "LexendDeca",
          fontSize: 23,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline),
      displayMedium: TextStyle(
          color: appColors.underlineTextDark,
          fontFamily: "LexendDeca",
          fontSize: 14,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold),
      displaySmall: TextStyle(
          color: appColors.underlineTextDark,
          fontFamily: "LexendDeca",
          fontSize: 14,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.normal),
      titleLarge: TextStyle(
          color: appColors.textDark,
          fontFamily: "LexendDeca",
          fontSize: 23,
          fontWeight: FontWeight.w700),
      titleMedium: TextStyle(
          color: appColors.cntTextDark1,
          fontFamily: "LexendDeca",
          fontSize: 20,
          fontWeight: FontWeight.w500),
      headlineSmall: TextStyle(
          color: appColors.cntTextDark1,
          fontFamily: "LexendDeca",
          fontSize: 14,
          fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(
        color: appColors.cntTextDark,
        fontFamily: "BricolageGrotesque",
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: TextStyle(
        color: appColors.cntTextDark1,
        fontFamily: "BricolageGrotesque",
        fontSize: 30,
        fontWeight: FontWeight.w500,
      ),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: appColors.roundedButtonColorDark1,
      focusColor: appColors.roundedButtonColorDark2,
      hoverColor: appColors.roundedButtonColorDark2,
    ),
    // iconTheme: IconThemeData(color: appColors.textBlackColorDark)
  );
}
