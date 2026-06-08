import 'package:bossy/BossyScreens/LoginScreens/LoginScreen.dart';
import 'package:bossy/BossyScreens/SplashScreens/SplashVideoScreen.dart';
import 'package:bossy/BossyServices/linkx_notification_service.dart';
import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

final GlobalKey<NavigatorState> linkxNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(linkxNavigatorKey);
  try {
    await ZegoUIKit().initLog();
    await ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI([
      ZegoUIKitSignalingPlugin(),
    ]);
  } catch (error) {
    debugPrint('Linkx ZEGO startup setup failed: $error');
  }
  await LinkxNotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  final bool showSplash;

  const MyApp({super.key, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: linkxNavigatorKey,
      title: 'Linkx',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF9F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFAA18),
          brightness: Brightness.light,
        ),
        fontFamily: 'Manrope',
      ),
      home: showSplash ? const SplashVideoScreen() : const LoginScreen(),
    );
  }
}
