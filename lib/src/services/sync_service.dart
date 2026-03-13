import 'dart:convert';

import '../models.dart';
import 'browser_bridge.dart';

class SyncService {
  SyncService(this._browserBridge);

  static const backupWebhookUrl =
      'https://discord.com/api/webhooks/1481864079122628690/kLToyGeJ1fjWFMZ-iGMDFGUJtw5z4mJhPuOTafiTYukuihco4gJVk9Pf39vRUzYJRWwj';

  final BrowserBridge _browserBridge;

  String buildSyncLink(PersistedState state) {
    final snapshot = BackupSnapshot.fromPersisted(state);
    final encoded = base64Url
        .encode(utf8.encode(jsonEncode(snapshot.toJson())))
        .replaceAll('=', '');
    final current = Uri.parse(_browserBridge.currentUrl);
    return current.replace(fragment: 'sync=$encoded').toString();
  }

  BackupSnapshot? parseSyncLink(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    String? payload;
    final asUri = Uri.tryParse(trimmed);
    if (asUri != null) {
      if (asUri.fragment.startsWith('sync=')) {
        payload = asUri.fragment.substring(5);
      } else if (asUri.queryParameters.containsKey('sync')) {
        payload = asUri.queryParameters['sync'];
      }
    }
    if (payload == null && trimmed.startsWith('#sync=')) {
      payload = trimmed.substring(6);
    }
    payload ??= trimmed.startsWith('sync=') ? trimmed.substring(5) : trimmed;
    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(payload)),
      );
      return BackupSnapshot.fromJson(
        jsonDecode(decoded) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  BackupSnapshot? parseSyncLinkFromCurrentUrl() {
    return parseSyncLink(_browserBridge.currentUrl);
  }

  Future<void> sendBackup(PersistedState state) async {
    final snapshot = BackupSnapshot.fromPersisted(state);
    final jsonPayload = jsonEncode(<String, dynamic>{
      ...snapshot.toJson(),
      'syncLink': buildSyncLink(state),
    });
    final summary =
        'RSS News Hub backup | feeds: ${snapshot.feeds.length} | ${snapshot.exportedAt.toIso8601String()}';
    final success = await _browserBridge.sendDiscordBackup(
      webhookUrl: backupWebhookUrl,
      summary: summary,
      jsonPayload: jsonPayload,
    );
    if (!success) {
      throw StateError('Không gửi được backup tới Discord.');
    }
  }

  void clearSyncFragment() {
    _browserBridge.clearSyncFragment();
  }
}
