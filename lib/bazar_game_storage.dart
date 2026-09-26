import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'bazar_game_models.dart';

abstract class BazarGameStateStore {
  Future<BazarGameState> load();
  Future<void> save(BazarGameState state);
  Future<void> clear();
}

class BazarGameStorage implements BazarGameStateStore {
  static const String _stateKey = 'baramot.bazar_game.v1';

  final SharedPreferencesAsync _prefs;

  BazarGameStorage({SharedPreferencesAsync? prefs})
      : _prefs = prefs ?? SharedPreferencesAsync();

  @override
  Future<BazarGameState> load() async {
    final raw = await _prefs.getString(_stateKey);
    if (raw == null || raw.trim().isEmpty) {
      return BazarGameState();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return BazarGameState();
      }

      return BazarGameState.fromMap(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } catch (_) {
      return BazarGameState();
    }
  }

  @override
  Future<void> save(BazarGameState state) async {
    await _prefs.setString(_stateKey, jsonEncode(state.toMap()));
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_stateKey);
  }
}
