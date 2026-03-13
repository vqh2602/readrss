import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

class LocalStorageService {
  static const _storageKey = 'readrss.persisted_state.v1';

  Future<PersistedState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return PersistedState.initial();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PersistedState.fromJson(decoded);
    } catch (_) {
      return PersistedState.initial();
    }
  }

  Future<void> save(PersistedState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, jsonEncode(state.toJson()));
  }
}
