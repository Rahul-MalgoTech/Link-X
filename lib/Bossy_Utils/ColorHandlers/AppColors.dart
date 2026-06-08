import 'package:flutter/material.dart';

class AppColors {
  /// Common colors
  final Color transparentColor = Colors.transparent;

  /// Light Mode colors

  final int lightPrimaryColor = 0xFF4FB9D1;
  final Map<int, Color> lightSwatchColor = const <int, Color>{
    50: Color(0xFF4FB9D1),
    100: Color(0xFF4FB9D1),
    200: Color(0xFF4FB9D1),
    300: Color(0xFF4FB9D1),
    400: Color(0xFF4FB9D1),
    500: Color(0xFF4FB9D1),
    600: Color(0xFF4FB9D1),
    700: Color(0xFF4FB9D1),
    800: Color(0xFF4FB9D1),
    900: Color(0xFF4FB9D1),
  };


  final Gradient lightBackgroundGradient = LinearGradient(
    colors: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

final Color greyContainerLight = Colors.white;
 final Color iconColorLight = Color(0XFF4a5565);
  final Color appPrimaryColorLight = Colors.white;
  final Color container = Color(0XFF153491);
  final Color appBodyColorLight1 =  Colors.white;
  final Color appBodyColorLight2 = const Color(0xFFf3f4f6);
  final Color createWalletTextLight1 = const Color(0xFF535454);
  final Color roundedButtonColorLight1 = const Color(0xFF26CD79);
  final Color roundedButtonColorLight2 =  Colors.white;
  final Color cardShadowLight = const Color(0xFFc7d0da);
  final Color textLight = Colors.black;
  final Color cntTextLight = const Color(0xFF4f6bcc);
  final Color cntTextLight1 = const Color(0xFF1c398e);
  final Color buttonLightDiableGrey2 = const Color(0XFFf3f4f6);
  final Color underlineTextLight = const Color(0XFF000000);
  final Color textBlackColorLight = Color(0xFFc7d0d);
  final Color hintTextLight = const Color(0XFFAAB2B8);
  final Color userTextLight = const Color(0XFFD2E9FF);
  final Color helperTextLight = const Color(0XFFD9D9D9);
  final Color greyTextLight = const Color(0XFF848C92);
  final Color hintLight = const Color(0xFFD4D4D4);
  final Color blackLight = const Color(0XFF11223E);
  final Color cardBackgroundLight =  Colors.white;
  final Color bgTextLight = Colors.black;
  final Color textBlackLight = const Color(0XFF000000);
  final Color errorSanckBarColorLight = Colors.red;
  final Color bottomColorsLight = Colors.blue;
  final Color SwapArrowRoundLight = Color(0XFF4EBBCA);

  final Color red = Colors.red;

  /// Dark Mode colors

  final int darkPrimaryColor = 0xFF4fb9d1;
  final Map<int, Color> darkSwatchColor = const <int, Color>{
    50: Color(0xFF4FB9D1),
    100: Color(0xFF4FB9D1),
    200: Color(0xFF4FB9D1),
    300: Color(0xFF4FB9D1),
    400: Color(0xFF4FB9D1),
    500: Color(0xFF4FB9D1),
    600: Color(0xFF4FB9D1),
    700: Color(0xFF4FB9D1),
    800: Color(0xFF4FB9D1),
    900: Color(0xFF4FB9D1),
  };

  final Gradient darkBackgroundGradient = LinearGradient(
    colors: [Color(0xFF192233), Color(0xFF1D2838)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final Color iconColorDark = Color(0XFFd1d5db);
  final Color greyContainerDark = Color(0XFF364153);
  final Color SwapArrowRoundDark = Color(0XFF202832);
  final Color containerDark = Color(0XFF153491).withOpacity(0.3);
  final Color appPrimartColorDark = Color(0xFF192233);
  final Color createWalletTextDark1 = const Color(0xFFB7B7B7);
  final Color appBodyColorDark1 = const Color(0xFF111829);
  final Color appBodyColorDark2 = const Color(0xFF1e2938);
  final Color roundedButtonColorDark1 = const Color(0xFF26CD79);
  final Color roundedButtonColorDark2 = const Color(0xFF313946);
  final Color buttonDiableGrey2 = Color(0XFF364153);
  final Color textDark = const Color(0XFFffffff);
  final Color cntTextDark = const Color(0XFF88befb);
  final Color cntTextDark1 = const Color(0XFF8ec5ff);
  final Color textBlackColorDark = Color(0xFF202832);
  final Color textBlackDark = const Color(0XFF000000);
  final Color hintTextDark = const Color(0XFFAAB2B8);
  final Color cardBackgroundDark = Color(0xFF1e2938);
  final Color cardShadowdark = const Color(0xFFc7d0da);
  final Color greyTextDark = const Color(0XFF848C92);
  final Color hintdark = const Color(0xFF202832);
  final Color bgTextDark = Colors.white;
  final Color underlineTextDark = const Color(0XFF000000);
  final Color userTextDark = const Color(0XFFD2E9FF);
  final Color helperTextDark = const Color(0XFFD9D9D9);
  final Color blackDark = const Color(0XFF11223E);
  final Color bottomColorDark = Color(0xFFB982FF);

  final Color errorSanckBarColorDark = Colors.red;
}

AppColors appColors = AppColors();
