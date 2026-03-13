import 'browser_bridge_stub.dart'
    if (dart.library.html) 'browser_bridge_web.dart';

enum NotificationAccess {
  unsupported,
  pending,
  granted,
  denied;

  String get label => switch (this) {
    NotificationAccess.unsupported => 'Khong ho tro',
    NotificationAccess.pending => 'Can cap quyen',
    NotificationAccess.granted => 'Da cap quyen',
    NotificationAccess.denied => 'Da chan',
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
