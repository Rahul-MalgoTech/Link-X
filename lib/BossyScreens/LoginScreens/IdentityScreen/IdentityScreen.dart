import 'package:bossy/BossyScreens/LoginScreens/AgeScreen.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/material.dart';

class IdentityScreen extends StatefulWidget {
  const IdentityScreen({super.key});

  @override
  State<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends State<IdentityScreen> {
  String _selected = 'Her';
  final LinkxApiClient _apiClient = LinkxApiClient();
  bool _isSaving = false;

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
              left: 18.5,
              top: 68,
              width: 365,
              height: 558.6767578125,
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
                      width: 333,
                      height: 56,
                      child: Text(
                        'how do you identify\nyourself?',
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 28 / 24,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 0,
                      top: 98.6767578125,
                      width: 333,
                      height: 32,
                      child: Text(
                        'You Can Edit This Information Later By Contacting Our\nCustomer Service.',
                        style: TextStyle(
                          color: Color(0xFF777370),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 16 / 12,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 98.5,
                      top: 150.6767578125,
                      width: 132,
                      height: 160,
                      child: GestureDetector(
                        onTap: () {
                          bossySelectionFeedback();
                          setState(() => _selected = 'Him');
                        },
                        child: _IdentityOption(
                          label: 'Him',
                          assetPath: 'assets/images/identify_him_3x.png',
                          selected: _selected == 'Him',
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 330.6767578125,
                      width: 329,
                      height: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE0E0E0),
                            ),
                          ),
                          const SizedBox(width: 13),
                          const Text(
                            'Or',
                            style: TextStyle(
                              color: Color(0x991E1E1E),
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 16 / 12,
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE0E0E0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 98.5,
                      top: 366.6767578125,
                      width: 132,
                      height: 160,
                      child: GestureDetector(
                        onTap: () {
                          bossySelectionFeedback();
                          setState(() => _selected = 'Her');
                        },
                        child: _IdentityOption(
                          label: 'Her',
                          assetPath: 'assets/images/identify_her_3x.png',
                          selected: _selected == 'Her',
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
              child: _BottomContinue(
                isLoading: _isSaving,
                onTap: () async {
                  if (_isSaving) return;
                  setState(() => _isSaving = true);
                  try {
                    await _apiClient.updateOnboarding({
                      'identity': _selected,
                      'onboardingStep': 'age',
                    });
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AgeScreen()),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityOption extends StatelessWidget {
  final String label;
  final String assetPath;
  final bool selected;

  const _IdentityOption({
    required this.label,
    required this.assetPath,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF00473E).withValues(alpha: 0.10)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: selected ? null : Border.all(color: const Color(0xFF00473E)),
      ),
      child: Column(
        children: [
          Image.asset(assetPath, width: 108, height: 108, fit: BoxFit.cover),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF00473E)
                    : const Color(0xFF1E1E1E),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 16 / 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomContinue extends StatelessWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _BottomContinue({required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          onTap: isLoading
              ? null
              : () {
                  bossySelectionFeedback();
                  onTap();
                },
          child: Center(
            child: isLoading
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
    );
  }
}
