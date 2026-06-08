import 'package:bossy/BossyScreens/LoginScreens/Repository/LoginRepo.dart';
import 'package:flutter/foundation.dart';

class BossyLoginViewModel extends ChangeNotifier {
  final BossyLoginRepo _repo;

  BossyLoginViewModel({BossyLoginRepo? repo})
    : _repo = repo ?? BossyLoginRepo();

  bool isLoading = false;

  Future<bool> sendOtp(String phoneNumber) async {
    isLoading = true;
    notifyListeners();
    final success = await _repo.sendOtp(phoneNumber);
    isLoading = false;
    notifyListeners();
    return success;
  }

  Future<BossyLoginResult?> verifyOtp(String phoneNumber, String otp) async {
    isLoading = true;
    notifyListeners();
    final success = await _repo.verifyOtp(phoneNumber, otp);
    isLoading = false;
    notifyListeners();
    return success;
  }
}
