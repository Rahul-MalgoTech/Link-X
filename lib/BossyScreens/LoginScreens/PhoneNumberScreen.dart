import 'package:bossy/BossyScreens/LoginScreens/OtpCodeScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/LoginRepo.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/material.dart';

class PhoneNumberScreen extends StatefulWidget {
  const PhoneNumberScreen({super.key});

  @override
  State<PhoneNumberScreen> createState() => _PhoneNumberScreenState();
}

class _PhoneNumberScreenState extends State<PhoneNumberScreen> {
  final TextEditingController _phoneController = TextEditingController();

  static const double figmaWidth = 402;
  static const double figmaHeight = 874;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

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
              left: 16,
              top: 68,
              width: 370,
              height: 242.6767578125,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 8.64094066619873,
                      height: 14.676755905151367,
                      child: GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Image.asset(
                          'assets/icons/arrow_back_ios_3x.png',
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      top: 34.6767578125,
                      width: 338,
                      height: 56,
                      child: Text(
                        'What’s your\nphone number?',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 28 / 24,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 98.6767578125,
                      width: 338,
                      height: 36,
                      child: Text(
                        'We Only Ask To Verify It’s You. It Won’t Show\nUp Anywhere, Including Your Profile',
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
                      left: 0,
                      top: 154.6767578125,
                      width: 106,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECECEC)),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 12,
                              top: 21,
                              width: 21,
                              height: 21,
                              child: Image.asset(
                                'assets/icons/india_flag_3x.png',
                              ),
                            ),
                            const Positioned(
                              left: 42,
                              top: 21.5,
                              width: 29,
                              height: 20,
                              child: Text(
                                '91+',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 20 / 16,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 77,
                              top: 27.5,
                              width: 14.676756282858832,
                              height: 8.640941307740093,
                              child: Transform.rotate(
                                angle: -1.57079632679,
                                child: Image.asset(
                                  'assets/icons/dropdown_arrow_3x.png',
                                  width: 8.64094066619873,
                                  height: 14.676755905151367,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 110,
                      top: 154.6767578125,
                      width: 228,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECECEC)),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              top: 19,
                              width: 138,
                              height: 17,
                              child: IgnorePointer(
                                ignoring: _phoneController.text.isNotEmpty,
                                child: Text(
                                  _phoneController.text.isEmpty
                                      ? 'Enter mobile number'
                                      : '',
                                  style: const TextStyle(
                                    color: Color(0xFF7B7B7B),
                                    fontFamily: 'Bricolage Grotesque',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    height: 1.21,
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                textAlignVertical: TextAlignVertical.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontFamily: 'Bricolage Grotesque',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.21,
                                ),
                                decoration: const InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 19.5,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 746,
              width: 362,
              height: 32,
              child: Text(
                'linkx will send you a text with averification code.message and\ndata rates may apply.',
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
            Positioned(
              left: 0,
              top: 794,
              width: 402,
              height: 80,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Material(
                  color: const Color(0xFFFAAE2B),
                  borderRadius: BorderRadius.circular(25),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(25),
                    onTap: () {
                      bossySelectionFeedback();
                      final phoneNumber = _phoneController.text.trim();
                      if (phoneNumber.isEmpty) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OtpCodeScreen(
                            phoneNumber: phoneNumber,
                            initialOtp: BossyLoginRepo.dummyOtp,
                          ),
                        ),
                      );
                    },
                    child: Center(
                      child: const Text(
                        'Send OTP',
                        style: TextStyle(
                          color: Color(0xFF00473E),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 20 / 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
