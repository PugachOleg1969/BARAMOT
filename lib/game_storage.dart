import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

class GameStorage {
  static const String _stateKey = 'baramot.game_state.v1';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<GameStateData> load() async {
    final raw = await _prefs.getString(_stateKey);
    if (raw == null || raw.isEmpty) {
      return GameStateData();
    }

    try {
      return GameStateData.fromJson(raw);
    } catch (_) {
      return GameStateData();
    }
  }

  Future<void> save(GameStateData state) async {
    await _prefs.setString(_stateKey, state.toJson());
  }

  Future<void> reset() async {
    await _prefs.remove(_stateKey);
  }
}
