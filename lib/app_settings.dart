import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Настройки приложения, которые меняет взрослый (ТЗ 3.6: «Звуки и анимации
/// можно отключить»). Хранятся отдельно от игрового прогресса, поэтому
/// «Начать заново» их не сбрасывает.
///
/// Использование: [AppSettings.instance] — единый экземпляр; виджеты
/// подписываются через ValueListenableBuilder / addListener.
class AppSettings extends ChangeNotifier {
  AppSettings._();

  static final AppSettings instance = AppSettings._();

  static const String _soundKey = 'baramot.settings.sound_enabled';
  static const String _animationsKey = 'baramot.settings.animations_enabled';

  SharedPreferencesAsync? _prefs;

  bool _soundEnabled = true;
  bool _animationsEnabled = true;

  bool get soundEnabled => _soundEnabled;
  bool get animationsEnabled => _animationsEnabled;

  /// Загружает сохранённые значения. Ошибка чтения не мешает запуску:
  /// остаются значения по умолчанию (звук и анимации включены).
  Future<void> load() async {
    try {
      final prefs = _prefs ??= SharedPreferencesAsync();
      _soundEnabled = await prefs.getBool(_soundKey) ?? true;
      _animationsEnabled = await prefs.getBool(_animationsKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Значения по умолчанию.
    }
  }

  Future<void> setSoundEnabled(bool value) async {
    if (_soundEnabled == value) return;
    _soundEnabled = value;
    notifyListeners();
    await _write(_soundKey, value);
  }

  Future<void> setAnimationsEnabled(bool value) async {
    if (_animationsEnabled == value) return;
    _animationsEnabled = value;
    notifyListeners();
    await _write(_animationsKey, value);
  }

  Future<void> _write(String key, bool value) async {
    try {
      final prefs = _prefs ??= SharedPreferencesAsync();
      await prefs.setBool(key, value);
    } catch (_) {
      // Не сохранилось — настройка действует до перезапуска.
    }
  }
}
