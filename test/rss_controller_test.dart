import 'package:flutter_test/flutter_test.dart';
import 'package:readrss/src/controller/rss_controller.dart';
import 'package:readrss/src/models.dart';
import 'package:readrss/src/services/browser_bridge.dart';
import 'package:readrss/src/services/local_storage_service.dart';
import 'package:readrss/src/services/rss_service.dart';

void main() {
  test(
    'refresh does not get stuck when storage rejects large cached payload',
    () async {
      final storage = _StorageRejectsCachedItems();
      final controller = RssController(
        rssService: _GrowingRssService(),
        storageService: storage,
        browserBridge: _FakeBrowserBridge(),
      );

      await controller.initialize();
      final message = await controller.addFeed(
        title: 'VNExpress',
        url: 'https://vnexpress.net/rss/tin-moi-nhat.rss',
        refreshInterval: const Duration(minutes: 15),
      );

      expect(message, contains('Đã thêm nguồn'));
      expect(controller.visibleArticles, isNotEmpty);
      expect(controller.isRefreshing, isFalse);

      await controller.refreshAll();

      expect(controller.isRefreshing, isFalse);
      expect(controller.visibleArticles, isNotEmpty);
      expect(storage.fallbackSaveCount, greaterThan(0));
    },
  );
}

class _GrowingRssService extends RssService {
  _GrowingRssService() : super();

  int _counter = 0;

  @override
  Future<FeedRefreshResult> refreshFeed(
    FeedSource source, {
    required bool adBlockEnabled,
  }) async {
    _counter += 1;
    final now = DateTime.now();
    final items = List<NewsItem>.generate(3, (index) {
      final seed = (_counter * 10) + index;
      return NewsItem(
        id: '${source.id}-$seed',
        feedId: source.id,
        feedTitle: source.title,
        title: 'Tin $seed',
        link: 'https://example.com/$seed',
        publishedAt: now.subtract(Duration(minutes: index)),
        summary: 'Tóm tắt $seed',
        content: 'Nội dung $seed',
      );
    });
    return FeedRefreshResult(
      source: source,
      resolvedTitle: source.title,
      items: items,
      fetchedAt: now,
    );
  }
}

class _StorageRejectsCachedItems extends LocalStorageService {
  int fallbackSaveCount = 0;

  @override
  Future<PersistedState> load() async {
    return PersistedState.initial();
  }

  @override
  Future<void> save(PersistedState state) async {
    final hasCachedItems = state.cachedArticlesByFeed.values.any(
      (items) => items.isNotEmpty,
    );
    if (hasCachedItems) {
      throw StateError('Quota exceeded');
    }
    fallbackSaveCount += 1;
  }
}

class _FakeBrowserBridge implements BrowserBridge {
  @override
  String get currentUrl => 'https://localhost';

  @override
  NotificationAccess get notificationAccess => NotificationAccess.granted;

  @override
  void clearSyncFragment() {}

  @override
  void openExternal(String url) {}

  @override
  Future<NotificationAccess> requestNotificationPermission() async {
    return NotificationAccess.granted;
  }

  @override
  Future<bool> sendDiscordBackup({
    required String webhookUrl,
    required String summary,
    required String jsonPayload,
  }) async {
    return true;
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
