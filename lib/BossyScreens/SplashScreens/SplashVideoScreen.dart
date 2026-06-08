import 'dart:async';

import 'package:bossy/BossyScreens/HomeScreens/BossyHomeShell.dart';
import 'package:bossy/BossyScreens/LoginScreens/LoginScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SplashVideoScreen extends StatefulWidget {
  const SplashVideoScreen({super.key});

  @override
  State<SplashVideoScreen> createState() => _SplashVideoScreenState();
}

class _SplashVideoScreenState extends State<SplashVideoScreen> {
  late final VideoPlayerController _controller;
  Timer? _fallbackTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/video/linxsplash.mp4');
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(false);
      await _controller.setVolume(0);
      if (!mounted) return;
      setState(() {});
      _controller.addListener(_handleVideoProgress);
      await _controller.play();
      _fallbackTimer = Timer(
        _controller.value.duration + const Duration(milliseconds: 500),
        _goToNextScreen,
      );
    } catch (_) {
      _goToNextScreen();
    }
  }

  void _handleVideoProgress() {
    final value = _controller.value;
    if (!value.isInitialized || value.isPlaying) return;
    if (value.position >= value.duration - const Duration(milliseconds: 120)) {
      _goToNextScreen();
    }
  }

  Future<void> _goToNextScreen() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    _fallbackTimer?.cancel();

    final hasToken = await LinkxApiClient.hasAuthToken();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) =>
            hasToken ? const BossyHomeShell() : const LoginScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.removeListener(_handleVideoProgress);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: _controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            : const ColoredBox(color: Colors.black),
      ),
    );
  }
}
