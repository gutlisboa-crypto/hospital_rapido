part of '../main.dart';

class AccessibilityState extends ChangeNotifier {
  bool highContrast = false, screenReaderSupport = false;
  double fontSizeScale = 1.0;

  Color get pageBackground => highContrast ? Colors.black : pageBackgroundColor;
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    highContrast = prefs.getBool('ubs_high_contrast') ?? false;
    screenReaderSupport = prefs.getBool('ubs_screen_reader') ?? false;
    fontSizeScale = prefs.getDouble('ubs_font_scale') ?? 1.0;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ubs_high_contrast', highContrast);
    await prefs.setBool('ubs_screen_reader', screenReaderSupport);
    await prefs.setDouble('ubs_font_scale', fontSizeScale);
  }

  void setContrast(bool value) {
    highContrast = value;
    notifyListeners();
    _save();
  }

  void setReaderSupport(bool value) {
    screenReaderSupport = value;
    notifyListeners();
    _save();
  }

  void setFontScale(double value) {
    fontSizeScale = value.clamp(.85, 1.30).toDouble();
    notifyListeners();
    _save();
  }

  void decreaseFont() {
    setFontScale(fontSizeScale > 1.15
        ? 1.15
        : fontSizeScale > 1.0
            ? 1.0
            : .85);
  }

  void increaseFont() {
    setFontScale(fontSizeScale < 1.0
        ? 1.0
        : fontSizeScale < 1.15
            ? 1.15
            : 1.30);
  }
}

final accessibility = AccessibilityState();
