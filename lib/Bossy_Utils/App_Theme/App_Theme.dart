import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme state manager using ChangeNotifier
class ThemeController with ChangeNotifier {
  final ThemePreferences _preferences = ThemePreferences();

  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  ThemeController() {
    _loadThemePreference();
  }

  void _loadThemePreference() async {
    _isDarkMode = await _preferences.getTheme();
    print("Theme loaded: $_isDarkMode");
    notifyListeners();
  }

  set isDarkMode(bool value) {
    _isDarkMode = value;
    _preferences.setDarkTheme(value);
    notifyListeners();
  }
}
/// Handles saving and retrieving theme preference from SharedPreferences
class ThemePreferences {
  static const THEME_STATUS = "THEMESTATUS";

  setDarkTheme(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    print(
        "Setting dark theme preference: $value"); // Print the value before storing

    prefs.setBool(THEME_STATUS, value);
  }

  Future<bool> getTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    return prefs.getBool(THEME_STATUS) ?? true;
  }
}

/// A toggle switch UI widget for light/dark mode
class ThemeToggleIcon extends StatefulWidget {
  const ThemeToggleIcon({super.key});

  @override
  State<ThemeToggleIcon> createState() => _ThemeToggleIconState();
}

class _ThemeToggleIconState extends State<ThemeToggleIcon> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeController>(
      builder: (context, themeController, child) {
        return GestureDetector(
          onTap: () {
            setState(() {
              themeController.isDarkMode = !themeController.isDarkMode;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColorDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              themeController.isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: Theme.of(context).iconTheme.color,
              size: 20,
            ),
          ),
        );
      },
    );
  }
}
