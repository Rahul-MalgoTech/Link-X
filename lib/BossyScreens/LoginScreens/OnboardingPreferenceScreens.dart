import 'dart:io';

import 'package:bossy/BossyScreens/HomeScreens/BossyHomeShell.dart';
import 'package:bossy/BossyScreens/LoginScreens/Repository/linkx_api_client.dart';
import 'package:bossy/BossyScreens/LoginScreens/Widgets/bossy_auth_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

const _bg = Color(0xFFFAF7F8);
const _green = Color(0xFF00473E);
const _yellow = Color(0xFFFAAE2B);
const _border = Color(0xFFECECEC);
const _muted = Color(0xFF777370);

class HeightScreen extends StatefulWidget {
  const HeightScreen({super.key});

  @override
  State<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends State<HeightScreen> {
  late final FixedExtentScrollController _controller;
  final List<int> _heights = List.generate(91, (index) => 140 + index);
  int _selectedIndex = 35;
  final LinkxApiClient _apiClient = LinkxApiClient();

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 893,
      child: _SetupCard(
        title: 'How tall are you ?',
        subtitle:
            'This information helps Linkx personalize the content you see and keep the Linkx community safe.',
        child: SizedBox(
          height: 468,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              CupertinoPicker(
                scrollController: _controller,
                itemExtent: 52,
                diameterRatio: 100,
                squeeze: 1,
                selectionOverlay: const SizedBox.shrink(),
                onSelectedItemChanged: (index) {
                  bossySelectionFeedback();
                  setState(() => _selectedIndex = index);
                },
                children: [
                  for (var i = 0; i < _heights.length; i++)
                    Center(
                      child: Text(
                        _formatHeight(_heights[i]),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: i == _selectedIndex
                              ? _green
                              : Colors.black.withValues(
                                  alpha: (i - _selectedIndex).abs() <= 3
                                      ? 0.50
                                      : 0.30,
                                ),
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 16,
                          fontWeight: i == _selectedIndex
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 20 / 16,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      onContinue: () async {
        await _apiClient.updateOnboarding({
          'heightCm': _heights[_selectedIndex],
          'onboardingStep': 'education',
        });
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EducationScreen()),
        );
      },
    );
  }

  String _formatHeight(int cm) {
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return '$cm Cm ($feet’$inches”)';
  }
}

class EducationScreen extends StatelessWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ChoiceScreen(
      title: 'Education Level',
      subtitle:
          'This information helps Linkx personalize the content you see and keep the Linkx community safe.',
      options: const [
        'autodidact',
        'Secondary Education',
        'College',
        'Bachelor',
        'Master',
        'Ph.D',
      ],
      initialSelectedIndex: 3,
      next: const PromptScreen(),
      apiField: 'educationLevel',
      nextStep: 'prompt',
    );
  }
}

class PromptScreen extends StatelessWidget {
  const PromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ChoiceScreen(
      title: 'What are you looking\nfor?',
      subtitle:
          'This information helps Linkx personalize the content you see and keep the Linkx community safe.',
      options: const [
        'Long-term realtionship',
        'Short-term relationship',
        'we’ll see (if the feeling is right)',
        'Friendship',
        'hangout',
        'Friends with benefits',
      ],
      initialSelectedIndex: 3,
      next: const HappitScreen(),
      apiField: 'lookingFor',
      nextStep: 'happiness',
    );
  }
}

class HappitScreen extends StatefulWidget {
  const HappitScreen({super.key});

  @override
  State<HappitScreen> createState() => _HappitScreenState();
}

class _HappitScreenState extends State<HappitScreen> {
  final Set<String> _selected = {'Cooking', 'Singing'};

  static const _creativeInterests = [
    'Singing',
    'Dancing',
    'Violinist',
    'Guitarist',
    'Music',
    'Painting',
  ];

  static const _lifestyleInterests = [
    'Cooking',
    'Explore Food',
    'Foodie',
    'Travel',
    'Fitness',
    'Coffee',
  ];

  static const _geekInterests = [
    'Comics',
    'Manga & Anime',
    'Chess',
    'Tech Think',
    'Mythology Nerd',
    'Twitch',
  ];

  void _toggle(String value) {
    bossySelectionFeedback();
    setState(() {
      if (_selected.contains(value)) {
        if (_selected.length > 1) _selected.remove(value);
      } else if (_selected.length < 12) {
        _selected.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 874,
      child: _SetupCard(
        title: 'What Makes you really\nhappy ?',
        subtitle: 'Choose interests so Home can show people like you.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MultiInterestSection(
              icon: 'assets/icons/happit_quirks_3x.png',
              iconSize: 20,
              title: 'Creative',
              options: _creativeInterests,
              selected: _selected,
              onToggle: _toggle,
            ),
            const SizedBox(height: 18),
            _MultiInterestSection(
              icon: 'assets/icons/happit_quirks_3x.png',
              iconSize: 20,
              title: 'Food & Lifestyle',
              options: _lifestyleInterests,
              selected: _selected,
              onToggle: _toggle,
            ),
            const SizedBox(height: 18),
            _MultiInterestSection(
              icon: 'assets/icons/happit_geek_3x.png',
              iconSize: 18,
              title: 'Geek',
              options: _geekInterests,
              selected: _selected,
              onToggle: _toggle,
            ),
          ],
        ),
      ),
      onContinue: () async {
        await LinkxApiClient().updateOnboarding({
          'happiness': _selected.toList(),
          'onboardingStep': 'children',
        });
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChildrenScreen()),
        );
      },
    );
  }
}

class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ChoiceScreen(
      title: 'Do you have children?',
      subtitle: 'Choose the option that suits your best',
      options: const [
        'i’ve got kids',
        'i don’t want any',
        'i have some, but want more',
        'I want kids one day',
      ],
      initialSelectedIndex: 3,
      next: const CigaretteScreen(),
      apiField: 'children',
      nextStep: 'habits',
    );
  }
}

class CigaretteScreen extends StatelessWidget {
  const CigaretteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 874,
      child: _SetupCard(
        title: 'Let’s talk about your\nlifestyle and habits',
        subtitle: 'Share as much about your habits as you’re comfortable with.',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TagSection(
              icon: 'assets/icons/happit_geek_3x.png',
              iconSize: 18,
              title: 'Drinking',
              rows: [
                [
                  _ChipData('Yes, I drink', width: 108),
                  _ChipData('I drink sometimes', width: 157),
                ],
                [
                  _ChipData('I rarely drink', width: 116),
                  _ChipData('No, I don’t drink', width: 138),
                ],
                [_ChipData('I’m sober', width: 88)],
              ],
              initialSelectedRow: 1,
              initialSelectedColumn: 1,
            ),
            SizedBox(height: 16),
            _TagSection(
              icon: 'assets/icons/happit_quirks_3x.png',
              iconSize: 20,
              title: 'Smoking',
              rows: [
                [
                  _ChipData('I Smoke sometimes', width: 169),
                  _ChipData('No, I don’t smoke', width: 148),
                ],
                [
                  _ChipData('Yes, I smoke', width: 111),
                  _ChipData('I’m trying to quit', width: 145),
                ],
              ],
              initialSelectedRow: 0,
              initialSelectedColumn: 1,
            ),
          ],
        ),
      ),
      onContinue: () async {
        await LinkxApiClient().updateOnboarding({
          'smoking': 'No, I don’t smoke',
          'onboardingStep': 'location',
        });
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocationPermissionScreen()),
        );
      },
    );
  }
}

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  Future<Position> _requestCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw const LinkxApiException('Please turn on location services.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LinkxApiException('Location permission is required.');
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      throw const LinkxApiException(
        'Location permission is permanently denied. Enable it in Settings.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
  }

  Future<String> _currentLocationLabel(Position position) async {
    try {
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (places.isEmpty) return '';

      final place = places.first;
      final parts =
          <String?>[
                place.subLocality,
                place.locality,
                place.subAdministrativeArea,
                place.administrativeArea,
              ]
              .where((part) => part != null && part.trim().isNotEmpty)
              .map((part) => part!.trim())
              .toList();

      final uniqueParts = <String>[];
      for (final part in parts) {
        final alreadyAdded = uniqueParts.any(
          (saved) => saved.toLowerCase() == part.toLowerCase(),
        );
        if (!alreadyAdded) uniqueParts.add(part);
      }

      if (uniqueParts.isNotEmpty) {
        return uniqueParts.take(3).join(', ');
      }

      final fallbackParts =
          <String?>[place.name, place.thoroughfare, place.street, place.country]
              .where((part) => part != null && part.trim().isNotEmpty)
              .map((part) => part!.trim())
              .toList();

      if (fallbackParts.isNotEmpty) return fallbackParts.take(2).join(', ');
    } catch (_) {}

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 874,
      bottomHeight: 110,
      buttonText: 'Enable Location',
      bottomExtra: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Image.asset(
            'assets/icons/location_privacy_3x.png',
            width: 13,
            height: 13,
          ),
          const SizedBox(width: 8),
          const Text(
            'Our Privacy Commitments',
            style: TextStyle(
              color: _muted,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      onContinue: () async {
        final position = await _requestCurrentLocation();
        final label = await _currentLocationLabel(position);
        await LinkxApiClient().updateOnboarding({
          'location': {
            'label': label,
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
          'onboardingStep': 'familyPlans',
        });
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KidsFamilyPlansScreen()),
        );
      },
      child: _SetupCard(
        width: 362,
        title: 'See who you crossed\npaths with',
        subtitle: '',
        subtitleBottomGap: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.asset(
                'assets/images/location_map.png',
                width: 330,
                height: 158,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select While Using The App So See Your Future\nCrushes. Don’t Worry, Other Happners Will Never See\nYour Real-Time Location',
              style: TextStyle(
                color: _muted,
                fontFamily: 'Bricolage Grotesque',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 16 / 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class KidsFamilyPlansScreen extends StatelessWidget {
  const KidsFamilyPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 874,
      child: _SetupCard(
        width: 362,
        title: 'Do you have kids or family\nPlans ?',
        subtitle:
            'Let’s Get Deeper. Feel Free To Skip If You’d Prefer Not To\nSay.',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TagSection(
              icon: 'assets/icons/family_baby_3x.png',
              iconSize: 20,
              title: 'Have Kids',
              rows: [
                [_ChipData('Have kids'), _ChipData('Don’t have kids')],
              ],
            ),
            SizedBox(height: 16),
            _TagSection(
              icon: 'assets/icons/family_baby_3x.png',
              iconSize: 20,
              title: 'Kids',
              rows: [
                [_ChipData('Don’t want kids'), _ChipData('Open to kids')],
                [_ChipData('Want kids'), _ChipData('Not Sure')],
              ],
              initialSelectedRow: 0,
              initialSelectedColumn: 1,
            ),
          ],
        ),
      ),
      onContinue: () async {
        await LinkxApiClient().updateOnboarding({
          'children': 'Open to kids',
          'onboardingStep': 'photos',
        });
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePhotoScreen()),
        );
      },
    );
  }
}

class ProfilePhotoScreen extends StatefulWidget {
  const ProfilePhotoScreen({super.key});

  @override
  State<ProfilePhotoScreen> createState() => _ProfilePhotoScreenState();
}

class _ProfilePhotoScreenState extends State<ProfilePhotoScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile?> _photos = List<XFile?>.filled(6, null);

  Future<void> _pickImage(int index) async {
    bossySelectionFeedback();
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );
    if (image == null || !mounted) return;
    setState(() => _photos[index] = image);
  }

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 874,
      child: _SetupCard(
        width: 362,
        title: 'Add 6 Photos',
        subtitle: '',
        subtitleBottomGap: 0,
        child: Column(
          children: [
            for (var row = 0; row < 3; row++) ...[
              Row(
                children: [
                  _PhotoSlot(
                    photo: _photos[row * 2],
                    onTap: () => _pickImage(row * 2),
                  ),
                  const SizedBox(width: 43),
                  _PhotoSlot(
                    photo: _photos[row * 2 + 1],
                    onTap: () => _pickImage(row * 2 + 1),
                  ),
                ],
              ),
              if (row != 2) const SizedBox(height: 32),
            ],
          ],
        ),
      ),
      onContinue: () async {
        await LinkxApiClient().uploadPhotos(
          _photos.whereType<XFile>().toList(),
        );
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StartScreen()),
        );
      },
    );
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  bool _isStarting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFF2F7F5),
      body: BossyScaledFigmaFrame(
        backgroundColor: const Color(0xFFF2F7F5),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/start_screen_figma.png',
                fit: BoxFit.fill,
              ),
            ),
            Positioned(
              left: 16,
              top: 810,
              width: 370,
              height: 48,
              child: Material(
                color: _yellow,
                borderRadius: BorderRadius.circular(25),
                child: InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: _isStarting
                      ? null
                      : () async {
                          bossySelectionFeedback();
                          setState(() => _isStarting = true);
                          try {
                            await LinkxApiClient().completeOnboarding();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const BossyHomeShell(),
                              ),
                              (_) => false,
                            );
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                          } finally {
                            if (mounted) setState(() => _isStarting = false);
                          }
                        },
                  child: Center(
                    child: _isStarting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _green,
                            ),
                          )
                        : const Text(
                            'Start',
                            style: TextStyle(
                              color: _green,
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

class _ChoiceScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final int initialSelectedIndex;
  final Widget next;
  final String? apiField;
  final String? nextStep;

  const _ChoiceScreen({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.initialSelectedIndex,
    required this.next,
    this.apiField,
    this.nextStep,
  });

  @override
  State<_ChoiceScreen> createState() => _ChoiceScreenState();
}

class _ChoiceScreenState extends State<_ChoiceScreen> {
  late int _selectedIndex = widget.initialSelectedIndex;

  @override
  Widget build(BuildContext context) {
    return _SetupScaffold(
      height: 874,
      child: _SetupCard(
        title: widget.title,
        subtitle: widget.subtitle,
        child: Column(
          children: [
            for (var i = 0; i < widget.options.length; i++) ...[
              GestureDetector(
                onTap: () {
                  bossySelectionFeedback();
                  setState(() => _selectedIndex = i);
                },
                child: _ChoiceRow(
                  text: widget.options[i],
                  selected: i == _selectedIndex,
                ),
              ),
              if (i != widget.options.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      onContinue: () async {
        if (widget.apiField != null) {
          await LinkxApiClient().updateOnboarding({
            widget.apiField!: widget.options[_selectedIndex],
            if (widget.nextStep != null) 'onboardingStep': widget.nextStep,
          });
        }
        if (!context.mounted) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => widget.next));
      },
    );
  }
}

class _SetupScaffold extends StatefulWidget {
  final double height;
  final double bottomHeight;
  final Widget child;
  final Widget? bottomExtra;
  final String buttonText;
  final Future<void> Function()? onContinue;

  const _SetupScaffold({
    required this.height,
    required this.child,
    this.bottomHeight = 80,
    this.bottomExtra,
    this.buttonText = 'Continue',
    this.onContinue,
  });

  @override
  State<_SetupScaffold> createState() => _SetupScaffoldState();
}

class _SetupScaffoldState extends State<_SetupScaffold> {
  bool _isLoading = false;

  Future<void> _continue() async {
    if (_isLoading) return;
    final onContinue = widget.onContinue;
    if (onContinue == null) return;

    setState(() => _isLoading = true);
    try {
      await onContinue();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _bg,
      body: BossyScaledFigmaFrame(
        backgroundColor: _bg,
        figmaHeight: widget.height,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: _bg)),
            Positioned(left: 19, top: 68, width: 365, child: widget.child),
            Positioned(
              left: 0,
              top: widget.height - widget.bottomHeight,
              width: 402,
              height: widget.bottomHeight,
              child: _BottomContinue(
                buttonText: widget.buttonText,
                extra: widget.bottomExtra,
                isLoading: _isLoading,
                onTap: _continue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  final double width;
  final String title;
  final String subtitle;
  final double subtitleBottomGap;
  final Widget child;

  const _SetupCard({
    this.width = 365,
    required this.title,
    required this.subtitle,
    this.subtitleBottomGap = 20,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
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
          Text(
            title,
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'Bricolage Grotesque',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 28 / 24,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: _muted,
                fontFamily: 'Bricolage Grotesque',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 16 / 12,
              ),
            ),
          ],
          if (subtitleBottomGap > 0) SizedBox(height: subtitleBottomGap),
          child,
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String text;
  final bool selected;

  const _ChoiceRow({required this.text, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: 48,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, right: 12),
      decoration: BoxDecoration(
        color: selected ? _green : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: selected ? null : Border.all(color: _border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.black.withValues(alpha: 0.5),
          fontFamily: 'Bricolage Grotesque',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 20 / 16,
        ),
      ),
    );
  }
}

class _MultiInterestSection extends StatelessWidget {
  final String icon;
  final double iconSize;
  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _MultiInterestSection({
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Image.asset(icon, width: iconSize, height: iconSize),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 20 / 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final option in options)
              _InterestPill(
                label: option,
                selected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _InterestPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _InterestPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _green : const Color(0xFFECECEC),
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.black.withValues(alpha: 0.5),
            fontFamily: 'Bricolage Grotesque',
            fontSize: 15,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 20 / 15,
          ),
        ),
      ),
    );
  }
}

class _TagSection extends StatefulWidget {
  final String icon;
  final double iconSize;
  final String title;
  final List<List<_ChipData>> rows;
  final int initialSelectedRow;
  final int initialSelectedColumn;

  const _TagSection({
    required this.icon,
    required this.iconSize,
    required this.title,
    required this.rows,
    this.initialSelectedRow = -1,
    this.initialSelectedColumn = -1,
  });

  @override
  State<_TagSection> createState() => _TagSectionState();
}

class _TagSectionState extends State<_TagSection> {
  late int _selectedRow = widget.initialSelectedRow;
  late int _selectedColumn = widget.initialSelectedColumn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Image.asset(
              widget.icon,
              width: widget.iconSize,
              height: widget.iconSize,
            ),
            const SizedBox(width: 8),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'Bricolage Grotesque',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 20 / 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < widget.rows.length; i++) ...[
          Row(
            children: [
              for (var j = 0; j < widget.rows[i].length; j++) ...[
                _TagChip(
                  data: widget.rows[i][j],
                  selected: i == _selectedRow && j == _selectedColumn,
                  onTap: () {
                    bossySelectionFeedback();
                    setState(() {
                      _selectedRow = i;
                      _selectedColumn = j;
                    });
                  },
                ),
                if (j != widget.rows[i].length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
          if (i != widget.rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ChipData {
  final String text;
  final double? width;

  const _ChipData(this.text, {this.width});
}

class _TagChip extends StatelessWidget {
  final _ChipData data;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        height: 36,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? _green : const Color(0xFFECECEC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          data.text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: selected
                ? Colors.white
                : Colors.black.withValues(alpha: 0.5),
            fontFamily: 'Bricolage Grotesque',
            fontSize: 16,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            height: 20 / 16,
          ),
        ),
      ),
    );

    if (data.width != null) {
      return SizedBox(width: data.width, child: child);
    }

    return Expanded(child: child);
  }
}

class _PhotoSlot extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onTap;

  const _PhotoSlot({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 143.5,
        height: 134,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(25)),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: photo == null ? _DashedBorderPainter() : null,
          child: photo == null
              ? Center(
                  child: Image.asset(
                    'assets/icons/profile_add_3x.png',
                    width: 28,
                    height: 28,
                  ),
                )
              : Image.file(File(photo!.path), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(25),
    );

    canvas.drawRRect(rrect, fillPaint);
    final path = Path()..addRRect(rrect.deflate(0.5));
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      const dash = 6.0;
      const gap = 5.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), borderPaint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomContinue extends StatelessWidget {
  final String buttonText;
  final Widget? extra;
  final VoidCallback? onTap;
  final bool isLoading;

  const _BottomContinue({
    this.buttonText = 'Continue',
    this.extra,
    this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, extra == null ? 16 : 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          GestureDetector(
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
                color: _yellow,
                borderRadius: BorderRadius.circular(25),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _green,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        color: _green,
                        fontFamily: 'Bricolage Grotesque',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 20 / 16,
                      ),
                    ),
            ),
          ),
          if (extra != null) ...[const SizedBox(height: 16), extra!],
        ],
      ),
    );
  }
}
