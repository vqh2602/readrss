import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readrss/src/models.dart';

void main() {
  test('reader settings persists theme preset in json', () {
    const settings = ReaderSettings(
      themeMode: ThemeMode.dark,
      themePreset: AppThemePreset.sakura,
      displayMode: FeedDisplayMode.cards,
      notificationsEnabled: true,
      adBlockEnabled: true,
      autoRefreshEnabled: false,
    );

    final restored = ReaderSettings.fromJson(settings.toJson());
    expect(restored.themeMode, ThemeMode.dark);
    expect(restored.themePreset, AppThemePreset.sakura);
    expect(restored.notificationsEnabled, isTrue);
    expect(restored.autoRefreshEnabled, isFalse);
  });

  test('reader settings fallback to default preset when missing', () {
    final restored = ReaderSettings.fromJson(<String, dynamic>{
      'themeMode': 'light',
      'displayMode': 'cards',
    });

    expect(restored.themePreset, AppThemePreset.ocean);
    expect(restored.themeMode, ThemeMode.light);
  });
}
