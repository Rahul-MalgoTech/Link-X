import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

typedef OtpReceivedCallback = void Function(String code);

class OtpAutofillService {
  OtpAutofillService._();

  static final OtpAutofillService instance = OtpAutofillService._();

  static const MethodChannel _channel = MethodChannel(
    'com.solla.pairever/otp_autofill',
  );

  OtpReceivedCallback? _onCodeReceived;
  bool _handlerAttached = false;

  Future<void> start({required OtpReceivedCallback onCodeReceived}) async {
    _onCodeReceived = onCodeReceived;
    _attachHandler();

    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<void>('startSmsUserConsent');
    } on PlatformException {
      // Manual entry and OS keyboard OTP suggestions still work as fallback.
    }
  }

  Future<void> stop() async {
    _onCodeReceived = null;
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<void>('stopSmsUserConsent');
    } on PlatformException {
      // Safe to ignore during dispose.
    }
  }

  void _attachHandler() {
    if (_handlerAttached) return;
    _handlerAttached = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onOtpReceived') return;

      final code = call.arguments?.toString().trim();
      if (code == null || code.isEmpty) return;

      _onCodeReceived?.call(code);
    });
  }
}
