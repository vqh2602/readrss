import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'browser_bridge.dart';

class _BrowserBridgeWeb implements BrowserBridge {
  String? _baseFaviconHref;
  String? _baseFaviconType;

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
    _syncFaviconBadge(count);
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

  void _syncFaviconBadge(int count) {
    final favicon = _ensureFaviconLink();
    _baseFaviconHref ??= favicon.href;
    _baseFaviconType ??= favicon.type;

    if (count <= 0) {
      if (_baseFaviconHref != null) {
        favicon
          ..href = _baseFaviconHref!
          ..type = _baseFaviconType ?? 'image/png';
      }
      return;
    }

    final display = count > 99 ? '99+' : '$count';
    final fontSize = display.length > 2 ? 17 : 20;
    final svg =
        '''
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#116A7B"/>
  <path d="M18 30c0-1.1.9-2 2-2h24c1.1 0 2 .9 2 2v18c0 1.1-.9 2-2 2H20c-1.1 0-2-.9-2-2V30Z" fill="none" stroke="#fff" stroke-width="3"/>
  <path d="M32 50V31" stroke="#fff" stroke-width="3" stroke-linecap="round"/>
  <path d="M20 31c4.3 0 8.5 1.6 12 4.6 3.5-3 7.7-4.6 12-4.6" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round"/>
  <circle cx="49" cy="15" r="13" fill="#E53935"/>
  <text x="49" y="20" text-anchor="middle" font-family="Arial,sans-serif" font-size="$fontSize" font-weight="700" fill="#fff">$display</text>
</svg>
''';

    favicon
      ..type = 'image/svg+xml'
      ..href = 'data:image/svg+xml,${Uri.encodeComponent(svg)}';
  }

  web.HTMLLinkElement _ensureFaviconLink() {
    final existing =
        web.document.querySelector('link[rel~="icon"]') as web.HTMLLinkElement?;
    if (existing != null) {
      return existing;
    }
    final created = web.HTMLLinkElement()
      ..rel = 'icon'
      ..type = 'image/png'
      ..href = 'favicon.png';
    web.document.head?.append(created);
    return created;
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
