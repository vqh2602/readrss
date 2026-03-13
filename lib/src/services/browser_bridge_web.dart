import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'browser_bridge.dart';

class _BrowserBridgeWeb implements BrowserBridge {
  @override
  String get currentUrl => html.window.location.href;

  @override
  NotificationAccess get notificationAccess {
    if (!html.Notification.supported) {
      return NotificationAccess.unsupported;
    }
    return _mapPermission(html.Notification.permission);
  }

  @override
  void clearSyncFragment() {
    final location = html.window.location;
    final target = '${location.pathname}${location.search}';
    html.window.history.replaceState(null, html.document.title, target);
  }

  @override
  void openExternal(String url) {
    html.window.open(url, '_blank');
  }

  @override
  Future<NotificationAccess> requestNotificationPermission() async {
    if (!html.Notification.supported) {
      return NotificationAccess.unsupported;
    }
    final permission = await html.Notification.requestPermission();
    return _mapPermission(permission);
  }

  @override
  Future<bool> sendDiscordBackup({
    required String webhookUrl,
    required String summary,
    required String jsonPayload,
  }) async {
    try {
      final formData = html.FormData();
      formData.append('content', summary);
      formData.appendBlob(
        'file',
        html.Blob(<Object>[jsonPayload], 'application/json'),
        'readrss-backup.json',
      );
      final options = js_util.jsify(<String, Object?>{
        'method': 'POST',
        'body': formData,
        'mode': 'no-cors',
      });
      await js_util.promiseToFuture<void>(
        js_util.callMethod(html.window, 'fetch', <Object?>[
          webhookUrl,
          options,
        ]),
      );
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
    html.Notification(title, body: body, icon: iconUrl, silent: false);
  }

  @override
  void syncUnreadBadge({required int count, required String appTitle}) {
    html.document.title = count > 0 ? '($count) $appTitle' : appTitle;
    final navigator = html.window.navigator;
    try {
      if (count > 0 && js_util.hasProperty(navigator, 'setAppBadge')) {
        js_util.callMethod(navigator, 'setAppBadge', <Object>[count]);
      } else if (js_util.hasProperty(navigator, 'clearAppBadge')) {
        js_util.callMethod(navigator, 'clearAppBadge', const <Object>[]);
      }
    } catch (_) {
      // Ignore unsupported browser badge APIs.
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

BrowserBridge createBrowserBridgeImpl() => _BrowserBridgeWeb();
