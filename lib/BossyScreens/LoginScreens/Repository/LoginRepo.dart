import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:bossy/BossyServices/linkx_chat_service.dart';

class BossyLoginRepo {
  static const String dummyOtp = '123456';

  final LinkxApiClient _apiClient;

  BossyLoginRepo({LinkxApiClient? apiClient})
    : _apiClient = apiClient ?? LinkxApiClient();

  Future<bool> sendOtp(String phoneNumber) async {
    final cleanedPhone = phoneNumber.trim();
    if (cleanedPhone.isEmpty) return false;
    try {
      await _apiClient.requestOtp(phoneNumber: cleanedPhone);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<BossyLoginResult?> verifyOtp(String phoneNumber, String otp) async {
    final cleanedOtp = otp.trim().isEmpty ? dummyOtp : otp.trim();
    if (phoneNumber.trim().isEmpty || cleanedOtp != dummyOtp) return null;
    try {
      LinkxChatService.instance.disconnect();
      final result = await _apiClient.verifyOtp(
        phoneNumber: phoneNumber.trim(),
        otp: cleanedOtp,
      );
      return BossyLoginResult(goHome: result.goHome);
    } catch (_) {
      return null;
    }
  }
}

class BossyLoginResult {
  final bool goHome;

  const BossyLoginResult({required this.goHome});
}
