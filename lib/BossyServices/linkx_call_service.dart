import 'dart:async';
import 'dart:convert';

import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

class LinkxCallService {
  LinkxCallService._();

  static final LinkxCallService instance = LinkxCallService._();

  static const int _appId = int.fromEnvironment(
    'ZEGO_APP_ID',
    defaultValue: 578128203,
  );
  static const String _appSign = String.fromEnvironment(
    'ZEGO_APP_SIGN',
    defaultValue:
        '79dcbcc0776fa272fdafc86474bfc7b0e587a20b84d6a90e0b0d907f23926eee',
  );
  static const String _resourceId = String.fromEnvironment(
    'ZEGO_RESOURCE_ID',
    defaultValue: 'pair_ever',
  );

  bool _initialized = false;
  String? _currentUserId;
  Future<void>? _initializing;

  bool get isInitialized => _initialized;

  Future<void> initializeForSignedInUser() async {
    await Permission.notification.request();
    final user = await LinkxApiClient().fetchCurrentUser();
    if (user.id.isEmpty) {
      throw const LinkxApiException('Unable to identify the signed-in user');
    }
    await _ensureInitialized(user);
  }

  Future<void> _ensureInitialized(LinkxCurrentUser user) async {
    if (_initialized && _currentUserId == user.id) return;

    if (_initializing != null) {
      await _initializing;
      if (_initialized && _currentUserId == user.id) return;
    }

    _initializing = _initialize(user);
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize(LinkxCurrentUser user) async {
    if (_initialized && _currentUserId != user.id) {
      await ZegoUIKitPrebuiltCallInvitationService().uninit();
      _initialized = false;
      _currentUserId = null;
    }

    await ZegoUIKitPrebuiltCallInvitationService().init(
      appID: _appId,
      appSign: _appSign,
      userID: user.id,
      userName: user.name,
      plugins: [ZegoUIKitSignalingPlugin()],
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoCallAndroidNotificationConfig(
          callIDVisibility: true,
          showOnLockedScreen: false,
          showOnFullScreen: false,
          callChannel: ZegoCallAndroidNotificationChannelConfig(
            channelID: 'linkx_call_channel',
            channelName: 'Linkx Incoming Calls',
            vibrate: true,
          ),
          missedCallChannel: ZegoCallAndroidNotificationChannelConfig(
            channelID: 'linkx_missed_call_channel',
            channelName: 'Linkx Missed Calls',
            vibrate: true,
          ),
        ),
        iOSNotificationConfig: ZegoCallIOSNotificationConfig(
          appName: 'Linkx',
          isSandboxEnvironment: true,
        ),
      ),
      invitationEvents: ZegoUIKitPrebuiltCallInvitationEvents(
        onIncomingCallReceived:
            (
              String callID,
              ZegoCallUser caller,
              ZegoCallInvitationType callType,
              List<ZegoCallUser> callees,
              String customData,
            ) {
              unawaited(_rejectUnmatchedIncomingCall(caller.id));
            },
        onOutgoingCallRejectedCauseBusy:
            (String callID, ZegoCallUser callee, String customData) {
              debugPrint('Linkx call rejected because ${callee.name} is busy');
            },
        onOutgoingCallDeclined:
            (String callID, ZegoCallUser callee, String customData) {
              debugPrint('Linkx call declined by ${callee.name}');
            },
        onOutgoingCallTimeout:
            (String callID, List<ZegoCallUser> callees, bool isVideoCall) {
              debugPrint('Linkx call timed out: $callID');
            },
      ),
      requireConfig: (ZegoCallInvitationData data) {
        final config = data.invitees.length > 1
            ? data.type == ZegoCallInvitationType.videoCall
                  ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                  : ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
            : data.type == ZegoCallInvitationType.videoCall
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

        config.avatarBuilder =
            (
              BuildContext context,
              Size size,
              ZegoUIKitUser? zegoUser,
              Map extraInfo,
            ) {
              if (zegoUser == null || user.avatarUrl.isEmpty) {
                return const SizedBox();
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(user.avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            };

        config.noResponseEnd = ZegoCallNoResponseEndConfig(
          enabled: true,
          timeoutSeconds: 60,
        );
        config
          ..turnOnCameraWhenJoining =
              data.type == ZegoCallInvitationType.videoCall
          ..turnOnMicrophoneWhenJoining = true
          ..useSpeakerWhenJoining =
              data.type == ZegoCallInvitationType.videoCall;
        return config;
      },
    );

    _initialized = true;
    _currentUserId = user.id;
  }

  Future<void> _rejectUnmatchedIncomingCall(String callerId) async {
    try {
      final allowed = await LinkxApiClient().authorizeCall(callerId);
      if (allowed) return;
    } catch (_) {}

    await ZegoUIKitPrebuiltCallInvitationService().reject(
      customData: jsonEncode({'reason': 'active_match_required'}),
    );
  }

  Future<LinkxCallResult> startCall({
    required String targetUserId,
    required String targetUserName,
    required bool isVideoCall,
  }) async {
    if (targetUserId.trim().isEmpty) {
      return const LinkxCallResult.failure(
        'This profile cannot receive calls.',
      );
    }

    try {
      final allowed = await LinkxApiClient().authorizeCall(targetUserId);
      if (!allowed) {
        return const LinkxCallResult.failure(
          'You can only call matched users.',
        );
      }
    } catch (error) {
      return LinkxCallResult.failure(error.toString());
    }

    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      return const LinkxCallResult.permissionFailure(
        'Microphone permission was denied.',
      );
    }

    if (isVideoCall) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        return const LinkxCallResult.permissionFailure(
          'Camera permission was denied.',
        );
      }
    }

    try {
      await initializeForSignedInUser();
      final callType = isVideoCall ? 'video' : 'audio';
      final callId =
          'linkx_${_currentUserId}_${targetUserId}_${callType}_${DateTime.now().millisecondsSinceEpoch}';
      final sent = await ZegoUIKitPrebuiltCallInvitationService().send(
        resourceID: _resourceId,
        invitees: [
          ZegoCallUser.fromUIKit(
            ZegoUIKitUser(id: targetUserId, name: targetUserName),
          ),
        ],
        isVideoCall: isVideoCall,
        callID: callId,
        customData: jsonEncode({
          'caller_id': _currentUserId,
          'callee_id': targetUserId,
          'call_type': callType,
        }),
        timeoutSeconds: 60,
      );
      return sent
          ? const LinkxCallResult.success()
          : const LinkxCallResult.failure(
              'Unable to send the call invitation.',
            );
    } catch (error) {
      debugPrint('Linkx ZEGO call failed: $error');
      return LinkxCallResult.failure(error.toString());
    }
  }

  Future<void> uninitialize() async {
    if (!_initialized) return;
    await ZegoUIKitPrebuiltCallInvitationService().uninit();
    _initialized = false;
    _currentUserId = null;
  }
}

class LinkxCallResult {
  final bool success;
  final String? message;
  final bool requiresAppSettings;

  const LinkxCallResult.success()
    : success = true,
      message = null,
      requiresAppSettings = false;

  const LinkxCallResult.failure(this.message)
    : success = false,
      requiresAppSettings = false;

  const LinkxCallResult.permissionFailure(this.message)
    : success = false,
      requiresAppSettings = true;
}
