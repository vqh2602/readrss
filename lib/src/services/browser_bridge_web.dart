import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_bridge.dart';

class _BrowserBridgeWeb implements BrowserBridge {
  @override
  String get currentUrl => web.window.location.href;

  @override
  NotificationAccess get notificationAccess {
    if (!web.window.has('Notification')) {
      return NotificationAccess.unsupported;
    }
    return _mapPermission(web.Notification.permission);
  }

  @override
  void clearSyncFragment() {
    final location = web.window.location;
    final target = '${location.pathname}${location.search}';
    web.window.history.replaceState(null, web.document.title, target);
  }

  @override
  void openExternal(String url) {
    web.window.open(url, '_blank');
  }

  @override
  Future<NotificationAccess> requestNotificationPermission() async {
    if (!web.window.has('Notification')) {
      return NotificationAccess.unsupported;
    }
    final permission = await web.Notification.requestPermission().toDart;
    return _mapPermission(permission.toDart);
  }

  @override
  Future<bool> sendDiscordBackup({
    required String webhookUrl,
    required String summary,
    required String jsonPayload,
  }) async {
    try {
      final formData = web.FormData();
      formData.append('content', summary.toJS);
      final blob = web.Blob(
        <JSAny>[jsonPayload.toJS].toJS,
        web.BlobPropertyBag(type: 'application/json'),
      );
      formData.append('file', blob, 'readrss-backup.json');
      await web.window
          .fetch(
            webhookUrl.toJS,
            web.RequestInit(method: 'POST', body: formData, mode: 'no-cors'),
          )
          .toDart;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void showNotification({
    required String title,
    required String body,
    String? iconUrl,
  }) {
    if (notificationAccess != NotificationAccess.granted) {
      return;
    }
    web.Notification(
      title,
      web.NotificationOptions(body: body, icon: iconUrl ?? '', silent: false),
    );
  }

  @override
  void syncUnreadBadge({required int count, required String appTitle}) {
    web.document.title = count > 0 ? '($count) $appTitle' : appTitle;
    if (!web.window.navigator.has('setAppBadge') ||
        !web.window.navigator.has('clearAppBadge')) {
      return;
    }
    if (count > 0) {
      web.window.navigator.setAppBadge(count).toDart.ignore();
    } else {
      web.window.navigator.clearAppBadge().toDart.ignore();
    }
  }

  NotificationAccess _mapPermission(String permission) {
    return switch (permission) {
      'granted' => NotificationAccess.granted,
      'denied' => NotificationAccess.denied,
      _ => NotificationAccess.pending,
    };
  }
}

extension on Future<Object?> {
  void ignore() {}
}

BrowserBridge createBrowserBridgeImpl() => _BrowserBridgeWeb();
