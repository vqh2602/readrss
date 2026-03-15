import 'browser_bridge.dart';

class _BrowserBridgeStub implements BrowserBridge {
  @override
  String get currentUrl => 'https://readrss.local/';

  @override
  NotificationAccess get notificationAccess => NotificationAccess.unsupported;

  @override
  void clearSyncFragment() {}

  @override
  void openExternal(String url) {}

  @override
  Future<NotificationAccess> requestNotificationPermission() async {
    return NotificationAccess.unsupported;
  }

  @override
  Future<bool> sendDiscordBackup({
    required String webhookUrl,
    required String summary,
    required String jsonPayload,
    required String syncLink,
  }) async {
    return false;
  }

  @override
  void showNotification({
    required String title,
    required String body,
    String? iconUrl,
  }) {}

  @override
  void syncUnreadBadge({required int count, required String appTitle}) {}
}

BrowserBridge createBrowserBridgeImpl() => _BrowserBridgeStub();
