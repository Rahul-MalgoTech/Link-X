import 'package:bossy/BossyScreens/LoginScreens/PhoneNumberScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/material.dart';

class LoginOptionsScreen extends StatelessWidget {
  const LoginOptionsScreen({super.key});

  static const double figmaWidth = 402;
  static const double figmaHeight = 874;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFAF7F8),
      body: BossyScaledFigmaFrame(
        backgroundColor: const Color(0xFFFAF7F8),
        figmaWidth: figmaWidth,
        figmaHeight: figmaHeight,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: const Color(0xFFFAF7F8))),
            Positioned(
              left: 0,
              top: 0,
              width: 402,
              height: 440,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF3ACFF), Color(0xFFF9AE51)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              top: 80,
              width: 402,
              height: 435,
              child: ClipRect(
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned(
                      left: 0,
                      top: 2,
                      width: 402,
                      height: 545,
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
              left: 0,
              top: 184,
              width: 402,
              height: 331,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFFFAF7F8).withValues(alpha: 0),
                      const Color(0xFFFAF7F8),
                      const Color(0xFFFAF7F8),
                    ],
                    stops: const [0, 0.76923, 0.98441],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 22.45,
              top: 66.24,
              width: 106,
              height: 22,
              child: Align(
                alignment: Alignment.centerLeft,
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
              top: 369,
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
                ),
              ),
            ),
            Positioned(
              left: 78,
              top: 455,
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
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 460,
              width: 362,
              height: 48,
              child: _LoginButton(
                assetPath: 'assets/icons/login_phone_icon_3x.png',
                label: 'Use Phone Number',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PhoneNumberScreen(),
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              left: 20,
              top: 520,
              width: 362,
              height: 48,
              child: _LoginButton(
                assetPath: 'assets/icons/login_google_icon_3x.png',
                label: 'Login With Google',
              ),
            ),
            const Positioned(
              left: 20,
              top: 580,
              width: 362,
              height: 48,
              child: _LoginButton(
                assetPath: 'assets/icons/login_facebook_icon_3x.png',
                label: 'Login With Facebook',
              ),
            ),
            const Positioned(
              left: 20,
              top: 640,
              width: 362,
              height: 48,
              child: _LoginButton(
                assetPath: 'assets/icons/login_apple_icon_3x.png',
                label: 'Login With Apple',
              ),
            ),
            Positioned(
              left: 20,
              top: 808,
              width: 362,
              height: 32,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'By signing up, you agree to our '),
                    TextSpan(text: 'Terms', style: _termsStyle),
                    TextSpan(text: '.', style: _termsStyle),
                    const TextSpan(text: ' See how we use your\ndata in our '),
                    TextSpan(text: 'privacy policy.', style: _termsStyle),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF1E1E1E).withValues(alpha: 0.60),
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _termsStyle = TextStyle(
    color: Color(0xFFFAAE2B),
    fontFamily: 'Bricolage Grotesque',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    decoration: TextDecoration.underline,
    decorationColor: Color(0xFFFAAE2B),
  );
}

class _LoginButton extends StatelessWidget {
  final String assetPath;
  final String label;
  final VoidCallback? onTap;

  const _LoginButton({
    required this.assetPath,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          bossySelectionFeedback();
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFECECEC)),
          ),
          child: Row(
            children: [
              Image.asset(assetPath, width: 24, height: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontFamily: 'Bricolage Grotesque',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
