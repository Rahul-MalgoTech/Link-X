import 'package:bossy/BossyScreens/LoginScreens/NameScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/LoginRepo.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:bossy/BossyScreens/HomeScreens/BossyHomeShell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OtpCodeScreen extends StatefulWidget {
  final String phoneNumber;
  final String initialOtp;

  const OtpCodeScreen({
    super.key,
    required this.phoneNumber,
    this.initialOtp = BossyLoginRepo.dummyOtp,
  });

  @override
  State<OtpCodeScreen> createState() => _OtpCodeScreenState();
}

class _OtpCodeScreenState extends State<OtpCodeScreen> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final BossyLoginRepo _loginRepo = BossyLoginRepo();
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _otpController.text = widget.initialOtp;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFAF7F8),
      body: BossyScaledFigmaFrame(
        backgroundColor: const Color(0xFFFAF7F8),
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: const Color(0xFFFAF7F8))),
            Positioned(
              left: 20,
              top: 68,
              width: 362,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Image.asset(
                        'assets/icons/arrow_back_ios_3x.png',
                        width: 8.64094066619873,
                        height: 14.676755905151367,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Enter your\nVerification code',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 28 / 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We Only Ask To Verify It's You. It Won't Show\nUp Anywhere, Including Your Profile",
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.60),
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        height: 18 / 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () => _focusNode.requestFocus(),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        children: [
                          AnimatedBuilder(
                            animation: _otpController,
                            builder: (context, _) {
                              return Row(
                                children: List.generate(6, (index) {
                                  final hasValue =
                                      _otpController.text.length > index;

                                  return Expanded(
                                    child: Container(
                                      height: 53,
                                      margin: EdgeInsets.only(
                                        right: index == 5 ? 0 : 8,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFECECEC),
                                        ),
                                      ),
                                      child: Text(
                                        hasValue
                                            ? _otpController.text[index]
                                            : '',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontFamily: 'Bricolage Grotesque',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                          Opacity(
                            opacity: 0,
                            child: TextField(
                              controller: _otpController,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              maxLength: 6,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 165,
                      child: Text.rich(
                        TextSpan(
                          text: "Didn't receive the code?\n",
                          children: const [
                            TextSpan(
                              text: 'Resend code',
                              style: TextStyle(
                                color: Color(0xFFFAAE2B),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFFFAAE2B),
                              ),
                            ),
                            TextSpan(text: ' in 42s'),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF7B7B7B),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 17 / 14,
                        ),
                      ),
                    ),
                  ],
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
                child: GestureDetector(
                  onTap: _isVerifying ? null : _continueWithDummyOtp,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAAE2B),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00473E),
                            ),
                          )
                        : const Text(
                            'Continue',
                            textAlign: TextAlign.center,
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
          ],
        ),
      ),
    );
  }

  Future<void> _continueWithDummyOtp() async {
    if (_isVerifying) return;
    bossySelectionFeedback();
    final otp = _otpController.text.trim();
    if (otp != BossyLoginRepo.dummyOtp) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Use dummy OTP 123456')));
      return;
    }

    setState(() => _isVerifying = true);
    final result = await _loginRepo.verifyOtp(widget.phoneNumber, otp);
    if (!mounted) return;
    setState(() => _isVerifying = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to verify OTP right now.')),
      );
      return;
    }

    if (result.goHome) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const BossyHomeShell()),
        (_) => false,
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NameScreen()),
      );
    }
  }
}
