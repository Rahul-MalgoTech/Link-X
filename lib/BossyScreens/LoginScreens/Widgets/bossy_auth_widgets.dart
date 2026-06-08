import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const bossyBackground = Color(0xFFFFF9F9);
const bossyText = Color(0xFF131313);
const bossyMuted = Color(0xFF777071);
const bossyYellow = Color(0xFFFFB11F);
const bossyInputBorder = Color(0xFFEFE7E7);
const bossyHeroPink = Color(0xFFEFA6D9);

const _linkxFeedbackChannel = MethodChannel('linkx/feedback');

void bossySelectionFeedback() {
  HapticFeedback.selectionClick();
  HapticFeedback.lightImpact();
  SystemSound.play(SystemSoundType.click);
  unawaited(_playNativeTick());
}

Future<void> _playNativeTick() async {
  try {
    await _linkxFeedbackChannel.invokeMethod<void>('playTick');
  } catch (_) {
    // Flutter's system click/haptic calls above are the fallback on platforms
    // without the native Linkx feedback channel.
  }
}

class BossyScaledFigmaFrame extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double figmaWidth;
  final double figmaHeight;

  const BossyScaledFigmaFrame({
    super.key,
    required this.child,
    required this.backgroundColor,
    this.figmaWidth = 402,
    this.figmaHeight = 874,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthScale = constraints.maxWidth / figmaWidth;
        final heightScale = constraints.maxHeight / figmaHeight;
        final isTallScreen =
            constraints.maxHeight / constraints.maxWidth >=
            figmaHeight / figmaWidth;
        final scale = isTallScreen ? widthScale : heightScale;
        final scaledHeight = figmaHeight * scale;
        final scaledWidth = figmaWidth * scale;

        if (!isTallScreen) {
          return ColoredBox(
            color: backgroundColor,
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: figmaWidth,
                  height: figmaHeight,
                  child: child,
                ),
              ),
            ),
          );
        }

        return ColoredBox(
          color: backgroundColor,
          child: SingleChildScrollView(
            physics: scaledHeight > constraints.maxHeight
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: scaledHeight < constraints.maxHeight
                  ? constraints.maxHeight
                  : scaledHeight,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: scaledWidth,
                  height: scaledHeight,
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: scale,
                    child: SizedBox(
                      width: figmaWidth,
                      height: figmaHeight,
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BossyLogo extends StatelessWidget {
  final Color color;
  final double fontSize;

  const BossyLogo({
    super.key,
    this.color = const Color(0xFFFF7D9A),
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      'LINKX',
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class BossyPrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final double height;

  const BossyPrimaryButton({
    super.key,
    required this.text,
    this.onTap,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bossyYellow,
          foregroundColor: bossyText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class BossyBackButton extends StatelessWidget {
  const BossyBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.chevron_left_rounded, size: 26),
    );
  }
}

class BossyTextField extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final int? maxLength;
  final Widget? prefix;

  const BossyTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.keyboardType,
    this.maxLength,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: bossyInputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          if (prefix != null) prefix!,
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              maxLength: maxLength,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(
                color: bossyText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: hintText,
                isCollapsed: true,
                hintStyle: const TextStyle(
                  color: Color(0xFFC7BFC0),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BossyAuthScaffold extends StatelessWidget {
  final Widget child;
  final bool showBack;

  const BossyAuthScaffold({
    super.key,
    required this.child,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bossyBackground,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: Row(children: [if (showBack) const BossyBackButton()]),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
