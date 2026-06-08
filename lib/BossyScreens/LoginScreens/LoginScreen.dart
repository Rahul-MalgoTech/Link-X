import 'package:bossy/BossyScreens/LoginScreens/LoginOptionsScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  static const double figmaWidth = 402;
  static const double figmaHeight = 874;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF3ACFF),
      body: BossyScaledFigmaFrame(
        backgroundColor: const Color(0xFFF3ACFF),
        figmaWidth: figmaWidth,
        figmaHeight: figmaHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3ACFF), Color(0xFFF9AE51)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -45,
              top: 341,
              width: 493,
              height: 533,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: 0,
                      top: 2,
                      width: 493,
                      height: 668,
                      child: Image.asset(
                        'assets/images/linkx_login_hero.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 166,
              top: 732,
              width: 69,
              height: 69,
              child: GestureDetector(
                key: const Key('login_cta_button'),
                onTap: () {
                  bossySelectionFeedback();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoginOptionsScreen(),
                    ),
                  );
                },
                child: Container(
                  width: 69,
                  height: 69,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFAAE2B),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF00473E),
                    size: 32,
                    weight: 700,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 148,
              top: 111,
              width: 106,
              height: 22,
              child: Center(
                child: Image.asset(
                  'assets/images/linkx_logo_white.png',
                  width: 106,
                  height: 22,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const Positioned(
              left: 90,
              top: 153,
              width: 223,
              height: 78,
              child: Text(
                'Find your\nPerfect Match',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  height: 1.21,
                  letterSpacing: 0,
                ),
              ),
            ),
            Positioned(
              left: 78,
              top: 239,
              width: 247,
              height: 36,
              child: Text(
                'Meet New People Spark Reat Connections\nAnd See Where It Goes',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.60),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
