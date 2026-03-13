import 'browser_bridge_stub.dart'
    if (dart.library.html) 'browser_bridge_web.dart';

enum NotificationAccess {
  unsupported,
  pending,
  granted,
  denied;

  String get label => switch (this) {
    NotificationAccess.unsupported => 'Không hỗ trợ',
    NotificationAccess.pending => 'Cần cấp quyền',
    NotificationAccess.granted => 'Đã cấp quyền',
    NotificationAccess.denied => 'Đã chặn',
  };
}

abstract class BrowserBridge {
  String get currentUrl;
  NotificationAccess get notificationAccess;

  Future<NotificationAccess> requestNotificationPermission();

  void showNotification({
    required String title,
    required String body,
    String? iconUrl,
  });

  void syncUnreadBadge({required int count, required String appTitle});

  void openExternal(String url);

  Future<bool> sendDiscordBackup({
    required String webhookUrl,
    required String summary,
    required String jsonPayload,
  });

  void clearSyncFragment();
}

BrowserBridge createBrowserBridge() => createBrowserBridgeImpl();
