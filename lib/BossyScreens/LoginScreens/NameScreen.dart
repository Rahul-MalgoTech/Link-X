import 'package:bossy/BossyScreens/LoginScreens/IdentityScreen/IdentityScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/material.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final TextEditingController _nameController = TextEditingController();
  final LinkxApiClient _apiClient = LinkxApiClient();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _apiClient.updateOnboarding({
        'firstName': _nameController.text.trim(),
        'onboardingStep': 'identity',
      });
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IdentityScreen()),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
              height: 210.6767578125,
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
                      width: 330,
                      height: 28,
                      child: Text(
                        'First name',
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
                      top: 70.6767578125,
                      width: 330,
                      height: 32,
                      child: Text(
                        'You Can Edit This Information Later By Contacting Our\nCustomer Service.',
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.60),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 16 / 12,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 122.6767578125,
                      width: 330,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFECECEC)),
                        ),
                        child: TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          textAlignVertical: TextAlignVertical.center,
                          onSubmitted: (_) => _goNext(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Enter your name',
                            hintStyle: TextStyle(
                              color: Color(0xFF7B7B7B),
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 19.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_nameController.text.trim().isNotEmpty)
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
                    onTap: _isSaving
                        ? null
                        : () {
                            bossySelectionFeedback();
                            _goNext();
                          },
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAAE2B),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: _isSaving
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
}
