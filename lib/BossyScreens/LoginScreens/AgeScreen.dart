import 'package:bossy/BossyScreens/LoginScreens/OnboardingPreferenceScreens.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AgeScreen extends StatefulWidget {
  const AgeScreen({super.key});

  @override
  State<AgeScreen> createState() => _AgeScreenState();
}

class _AgeScreenState extends State<AgeScreen> {
  final List<String> _months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _yearController;

  int _monthIndex = 10;
  int _dayIndex = 30;
  int _yearIndex = 18;
  bool _showStarOnProfile = true;
  bool _isSaving = false;
  final LinkxApiClient _apiClient = LinkxApiClient();

  @override
  void initState() {
    super.initState();
    _monthController = FixedExtentScrollController(initialItem: _monthIndex);
    _dayController = FixedExtentScrollController(initialItem: _dayIndex);
    _yearController = FixedExtentScrollController(initialItem: _yearIndex);
  }

  @override
  void dispose() {
    _monthController.dispose();
    _dayController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  List<String> get _days =>
      List.generate(31, (index) => (index + 1).toString().padLeft(2, '0'));

  List<String> get _years =>
      List.generate(80, (index) => (1980 + index).toString());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFFAF7F8),
      body: BossyScaledFigmaFrame(
        backgroundColor: const Color(0xFFFAF7F8),
        figmaHeight: 893,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: const Color(0xFFFAF7F8))),
            Positioned(
              left: 19,
              top: 68,
              width: 365,
              child: Column(
                children: [
                  Container(
                    width: 365,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          'How old are you ?',
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            height: 28 / 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'This Information Helps Linkx Personalize The Content You\nSee And Keep The Linkx Community Safe.',
                          style: TextStyle(
                            color: Color(0xFF777370),
                            fontFamily: 'Bricolage Grotesque',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 16 / 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 364,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00473E,
                                  ).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _DateWheel(
                                      controller: _monthController,
                                      values: _months,
                                      selectedIndex: _monthIndex,
                                      onSelectedItemChanged: (index) {
                                        bossySelectionFeedback();
                                        setState(() => _monthIndex = index);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: _DateWheel(
                                      controller: _dayController,
                                      values: _days,
                                      selectedIndex: _dayIndex,
                                      onSelectedItemChanged: (index) {
                                        bossySelectionFeedback();
                                        setState(() => _dayIndex = index);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: _DateWheel(
                                      controller: _yearController,
                                      values: _years,
                                      selectedIndex: _yearIndex,
                                      onSelectedItemChanged: (index) {
                                        bossySelectionFeedback();
                                        setState(() => _yearIndex = index);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 365,
                    height: 64,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFECECEC)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Your star is: Gemini. ',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                TextSpan(
                                  text: _showStarOnProfile
                                      ? 'Display On your\nProfile? You can Update...'
                                      : 'Hidden From your\nProfile? You can Update...',
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              color: Colors.black,
                              fontFamily: 'Bricolage Grotesque',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                        Switch(
                          value: _showStarOnProfile,
                          activeThumbColor: Colors.white,
                          activeTrackColor: const Color(0xFF00473E),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFECECEC),
                          onChanged: (value) {
                            bossySelectionFeedback();
                            setState(() => _showStarOnProfile = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 813,
              width: 402,
              height: 80,
              child: _BottomContinue(
                isLoading: _isSaving,
                onTap: () async {
                  if (_isSaving) return;
                  final month = _monthIndex + 1;
                  final day = int.parse(_days[_dayIndex]);
                  final year = int.parse(_years[_yearIndex]);
                  setState(() => _isSaving = true);
                  try {
                    await _apiClient.updateOnboarding({
                      'birthDate': DateTime(year, month, day).toIso8601String(),
                      'showStarOnProfile': _showStarOnProfile,
                      'onboardingStep': 'height',
                    });
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HeightScreen()),
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

class _DateWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<String> values;
  final int selectedIndex;
  final ValueChanged<int> onSelectedItemChanged;

  const _DateWheel({
    required this.controller,
    required this.values,
    required this.selectedIndex,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 52,
      diameterRatio: 100,
      squeeze: 1,
      selectionOverlay: const SizedBox.shrink(),
      onSelectedItemChanged: onSelectedItemChanged,
      children: [
        for (var i = 0; i < values.length; i++)
          Center(
            child: Text(
              values[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: i == selectedIndex
                    ? const Color(0xFF00473E)
                    : Colors.black.withValues(
                        alpha: (i - selectedIndex).abs() <= 2 ? 0.50 : 0.30,
                      ),
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: i == selectedIndex
                    ? FontWeight.w600
                    : FontWeight.w500,
                height: 20 / 16,
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomContinue extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const _BottomContinue({this.onTap, this.isLoading = false});

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
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                bossySelectionFeedback();
                onTap?.call();
              },
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAAE2B),
            borderRadius: BorderRadius.circular(25),
          ),
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
    );
  }
}
