import 'dart:async';

import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class LinkxRoomAudioPage extends StatefulWidget {
  final LinkxRoom room;
  final bool video;

  const LinkxRoomAudioPage({super.key, required this.room, this.video = false});

  @override
  State<LinkxRoomAudioPage> createState() => _LinkxRoomAudioPageState();
}

class _LinkxRoomAudioPageState extends State<LinkxRoomAudioPage> {
  static const int _appId = int.fromEnvironment(
    'ZEGO_APP_ID',
    defaultValue: 578128203,
  );
  static const String _appSign = String.fromEnvironment(
    'ZEGO_APP_SIGN',
    defaultValue:
        '79dcbcc0776fa272fdafc86474bfc7b0e587a20b84d6a90e0b0d907f23926eee',
  );

  LinkxCurrentUser? _user;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final microphone = await Permission.microphone.request();
    final camera = widget.video ? await Permission.camera.request() : null;
    if (!microphone.isGranted || (widget.video && camera?.isGranted != true)) {
      if (mounted) {
        setState(
          () => _error = widget.video
              ? 'Camera and microphone permissions are required for video rooms.'
              : 'Microphone permission is required for audio rooms.',
        );
      }
      return;
    }
    try {
      final user = await LinkxApiClient().fetchCurrentUser();
      if (mounted) setState(() => _user = user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _finishRoom() async {
    try {
      if (widget.room.isHost) {
        await LinkxApiClient().endRoom(widget.room.id);
      } else {
        await LinkxApiClient().leaveRoom(widget.room.id);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final user = _user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final config =
        (widget.video
              ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
              : ZegoUIKitPrebuiltCallConfig.groupVoiceCall())
          ..turnOnCameraWhenJoining = widget.video
          ..turnOnMicrophoneWhenJoining = widget.room.isHost
          ..useSpeakerWhenJoining = true
          ..bottomMenuBar.buttons = widget.video
              ? [
                  ZegoCallMenuBarButtonName.toggleCameraButton,
                  ZegoCallMenuBarButtonName.switchCameraButton,
                  ZegoCallMenuBarButtonName.toggleMicrophoneButton,
                  ZegoCallMenuBarButtonName.switchAudioOutputButton,
                  ZegoCallMenuBarButtonName.hangUpButton,
                ]
              : [
                  ZegoCallMenuBarButtonName.toggleMicrophoneButton,
                  ZegoCallMenuBarButtonName.switchAudioOutputButton,
                  ZegoCallMenuBarButtonName.hangUpButton,
                ];

    return ZegoUIKitPrebuiltCall(
      appID: _appId,
      appSign: _appSign,
      userID: user.id,
      userName: user.name,
      callID: widget.room.zegoRoomId,
      config: config,
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) {
          unawaited(_finishRoom());
          defaultAction();
        },
      ),
    );
  }
}
