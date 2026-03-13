import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/browser_bridge.dart';
import '../services/local_storage_service.dart';
import '../services/rss_service.dart';
import '../services/sync_service.dart';

class RssController extends ChangeNotifier {
  RssController({
    RssService? rssService,
    LocalStorageService? storageService,
    BrowserBridge? browserBridge,
    SyncService? syncService,
  }) : _browserBridge = browserBridge ?? createBrowserBridge(),
       _rssService = rssService ?? RssService(),
       _storageService = storageService ?? LocalStorageService() {
    _syncService = syncService ?? SyncService(_browserBridge);
  }

  static const allFeedsId = '__all__';
  static const _maxKnownIds = 500;

  final BrowserBridge _browserBridge;
  final RssService _rssService;
  final LocalStorageService _storageService;
  late final SyncService _syncService;

  final Map<String, List<NewsItem>> _itemsByFeed = <String, List<NewsItem>>{};
  final Set<String> _knownArticleIds = <String>{};
  final Set<String> _unreadArticleIds = <String>{};

  List<FeedSource> _feeds = <FeedSource>[];
  ReaderSettings _settings = const ReaderSettings();
  Timer? _refreshTicker;
  String _selectedFeedId = allFeedsId;
  bool _isInitializing = true;
  bool _isRefreshing = false;
  DateTime? _lastRefreshAt;
  String? _lastStatus;

  bool get isInitializing => _isInitializing;
  bool get isRefreshing => _isRefreshing;
  bool get hasFeeds => _feeds.isNotEmpty;
  String get selectedFeedId => _selectedFeedId;
  DateTime? get lastRefreshAt => _lastRefreshAt;
  String? get lastStatus => _lastStatus;
  ReaderSettings get settings => _settings;
  List<FeedSource> get feeds => List<FeedSource>.unmodifiable(_feeds);
  NotificationAccess get notificationAccess =>
      _browserBridge.notificationAccess;
  int get unreadCount => _unreadArticleIds.length;

  List<NewsItem> get visibleArticles {
    final items = _selectedFeedId == allFeedsId
        ? _itemsByFeed.values.expand((feedItems) => feedItems).toList()
        : List<NewsItem>.from(
            _itemsByFeed[_selectedFeedId] ?? const <NewsItem>[],
          );
    items.sort((left, right) => right.publishedAt.compareTo(left.publishedAt));
    return items;
  }

  List<NewsItem> get sideArticles {
    final items = _selectedFeedId == allFeedsId
        ? _itemsByFeed.values.expand((feedItems) => feedItems).toList()
        : List<NewsItem>.from(
            _itemsByFeed[_selectedFeedId] ?? const <NewsItem>[],
          );
    items.sort((left, right) => right.publishedAt.compareTo(left.publishedAt));
    return items.take(8).toList();
  }

  FeedSource? get selectedFeed {
    for (final feed in _feeds) {
      if (feed.id == _selectedFeedId) {
        return feed;
      }
    }
    return null;
  }

  List<NewsItem> articlesForFeed(String feedId) {
    final items = List<NewsItem>.from(
      _itemsByFeed[feedId] ?? const <NewsItem>[],
    );
    items.sort((left, right) => right.publishedAt.compareTo(left.publishedAt));
    return items;
  }

  int articleCountForFeed(String feedId) {
    if (_itemsByFeed.containsKey(feedId)) {
      return _itemsByFeed[feedId]?.length ?? 0;
    }
    final feed = _feeds.where((item) => item.id == feedId).firstOrNull;
    return feed?.cachedArticleCount ?? 0;
  }

  bool isArticleUnread(String articleId) {
    return _unreadArticleIds.contains(articleId);
  }

  Future<void> initialize() async {
    final restored = await _storageService.load();
    _feeds = restored.feeds;
    _settings = restored.settings;
    _itemsByFeed
      ..clear()
      ..addAll(
        restored.cachedArticlesByFeed.map(
          (feedId, items) => MapEntry(feedId, List<NewsItem>.from(items)),
        ),
      );
    _knownArticleIds
      ..clear()
      ..addAll(restored.knownArticleIds);
    _unreadArticleIds
      ..clear()
      ..addAll(restored.unreadArticleIds);

    final imported = _syncService.parseSyncLinkFromCurrentUrl();
    if (imported != null) {
      final state = imported.toPersistedState();
      _feeds = state.feeds;
      _settings = state.settings;
      _itemsByFeed.clear();
      _knownArticleIds.clear();
      _unreadArticleIds.clear();
      _syncService.clearSyncFragment();
      _lastStatus = 'Đã nhập dữ liệu từ link đồng bộ.';
      await _storageService.save(state);
    }

    _isInitializing = false;
    _syncBadge();
    _startAutoRefresh();
    notifyListeners();

    if (_feeds.isNotEmpty) {
      await refreshAll(isInitial: true, triggerNotifications: false);
    }
  }

  void setSelectedFeed(String feedId) {
    _selectedFeedId = feedId;
    notifyListeners();
  }

  Future<FeedPreview> previewFeed(String url) {
    return _rssService.previewFeed(
      url,
      adBlockEnabled: _settings.adBlockEnabled,
    );
  }

  Future<String> addFeed({
    required String title,
    required String url,
    required Duration refreshInterval,
    FeedPreview? preview,
  }) async {
    final normalizedUrl = url.trim();
    final duplicate = _feeds.any(
      (feed) => feed.url.toLowerCase() == normalizedUrl.toLowerCase(),
    );
    if (duplicate) {
      throw StateError('Nguồn RSS này đã tồn tại.');
    }

    final resolvedTitle = preview != null && preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : title.trim();
    final feed = FeedSource(
      id: _createFeedId(normalizedUrl),
      title: resolvedTitle.isEmpty ? normalizedUrl : resolvedTitle,
      url: normalizedUrl,
      refreshInterval: refreshInterval,
    );

    _feeds = <FeedSource>[feed, ..._feeds];
    _selectedFeedId = feed.id;
    await _persist();
    notifyListeners();
    await refreshFeed(feed.id, isInitial: true, triggerNotifications: false);
    return 'Đã thêm nguồn ${feed.title}.';
  }

  Future<String> removeFeed(String feedId) async {
    final removed = _feeds.where((feed) => feed.id == feedId).firstOrNull;
    _feeds = _feeds.where((feed) => feed.id != feedId).toList();
    _itemsByFeed.remove(feedId);
    if (_selectedFeedId == feedId) {
      _selectedFeedId = allFeedsId;
    }
    _rebuildKnownIds();
    await _persist();
    notifyListeners();
    return removed == null
        ? 'Không tìm thấy feed cần xóa.'
        : 'Đã xóa nguồn ${removed.title}.';
  }

  Future<String> updateFeedRefreshInterval(
    String feedId,
    Duration refreshInterval,
  ) async {
    final index = _feeds.indexWhere((feed) => feed.id == feedId);
    if (index == -1) {
      throw StateError('Không tìm thấy feed cần cập nhật.');
    }
    _feeds[index] = _feeds[index].copyWith(refreshInterval: refreshInterval);
    await _persist();
    notifyListeners();
    return 'Đã cập nhật chu kỳ làm mới cho ${_feeds[index].title}.';
  }

  Future<void> refreshAll({
    bool isInitial = false,
    bool triggerNotifications = false,
  }) async {
    if (_isRefreshing) {
      return;
    }
    _isRefreshing = true;
    _lastStatus = 'Đang cập nhật tất cả nguồn...';
    notifyListeners();

    final updatedFeeds = <FeedSource>[];
    final allNewItems = <NewsItem>[];
    for (final feed in _feeds) {
      updatedFeeds.add(
        await _refreshSingleFeed(
          feed,
          isInitial: isInitial,
          triggerNotifications: triggerNotifications,
          newItemsAccumulator: allNewItems,
        ),
      );
    }

    _feeds = updatedFeeds;
    _isRefreshing = false;
    _lastRefreshAt = DateTime.now();
    _lastStatus = allNewItems.isEmpty
        ? 'Cập nhật xong, chưa có tin mới.'
        : 'Cập nhật xong, có ${allNewItems.length} tin mới.';
    _syncBadge();
    await _persist();
    notifyListeners();
  }

  Future<void> refreshFeed(
    String feedId, {
    bool isInitial = false,
    bool triggerNotifications = false,
  }) async {
    final index = _feeds.indexWhere((feed) => feed.id == feedId);
    if (index == -1 || _isRefreshing) {
      return;
    }
    _isRefreshing = true;
    notifyListeners();

    final newItems = <NewsItem>[];
    _feeds[index] = await _refreshSingleFeed(
      _feeds[index],
      isInitial: isInitial,
      triggerNotifications: triggerNotifications,
      newItemsAccumulator: newItems,
    );

    _isRefreshing = false;
    _lastRefreshAt = DateTime.now();
    _lastStatus = newItems.isEmpty
        ? 'Không có tin mới từ ${_feeds[index].title}.'
        : '${_feeds[index].title} có ${newItems.length} tin mới.';
    _syncBadge();
    await _persist();
    notifyListeners();
  }

  Future<String> requestNotificationPermission() async {
    final access = await _browserBridge.requestNotificationPermission();
    if (access == NotificationAccess.granted) {
      _settings = _settings.copyWith(notificationsEnabled: true);
      await _persist();
      notifyListeners();
      return 'Đã cấp quyền thông báo trình duyệt.';
    }
    if (access == NotificationAccess.denied) {
      _settings = _settings.copyWith(notificationsEnabled: false);
      await _persist();
      notifyListeners();
      throw StateError('Trình duyệt đang chặn thông báo cho trang này.');
    }
    throw StateError('Trình duyệt không hỗ trợ hoặc chưa cấp quyền thông báo.');
  }

  Future<String> setNotificationsEnabled(bool enabled) async {
    if (enabled && notificationAccess != NotificationAccess.granted) {
      return requestNotificationPermission();
    }
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    await _persist();
    notifyListeners();
    return enabled ? 'Đã bật thông báo tin mới.' : 'Đã tắt thông báo tin mới.';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _persist();
    notifyListeners();
  }

  Future<void> setDisplayMode(FeedDisplayMode mode) async {
    _settings = _settings.copyWith(displayMode: mode);
    await _persist();
    notifyListeners();
  }

  Future<void> setAdBlockEnabled(bool enabled) async {
    _settings = _settings.copyWith(adBlockEnabled: enabled);
    await _persist();
    notifyListeners();
  }

  Future<void> setAutoRefreshEnabled(bool enabled) async {
    _settings = _settings.copyWith(autoRefreshEnabled: enabled);
    await _persist();
    notifyListeners();
  }

  void markArticleRead(String articleId) {
    if (_unreadArticleIds.remove(articleId)) {
      _syncBadge();
      unawaited(_persist());
      notifyListeners();
    }
  }

  void openOriginalArticle(String url) {
    _browserBridge.openExternal(url);
  }

  String buildSyncLink() {
    return _syncService.buildSyncLink(_buildPersistedState());
  }

  Future<String> importSyncLink(String rawLink) async {
    final snapshot = _syncService.parseSyncLink(rawLink);
    if (snapshot == null) {
      throw const FormatException('Link đồng bộ không hợp lệ.');
    }

    final restored = snapshot.toPersistedState();
    _feeds = restored.feeds;
    _settings = restored.settings;
    _itemsByFeed.clear();
    _knownArticleIds.clear();
    _unreadArticleIds.clear();
    _selectedFeedId = allFeedsId;
    _lastStatus = 'Đã nhập ${_feeds.length} nguồn từ link đồng bộ.';
    await _persist();
    notifyListeners();

    if (_feeds.isNotEmpty) {
      await refreshAll(isInitial: true, triggerNotifications: false);
    }
    return 'Đã nhập dữ liệu thành công.';
  }

  Future<String> backupToDiscord() async {
    await _syncService.sendBackup(_buildPersistedState());
    return 'Đã gửi bản sao lưu lên Discord webhook.';
  }

  Future<FeedSource> _refreshSingleFeed(
    FeedSource feed, {
    required bool isInitial,
    required bool triggerNotifications,
    required List<NewsItem> newItemsAccumulator,
  }) async {
    try {
      final refreshed = await _rssService.refreshFeed(
        feed,
        adBlockEnabled: _settings.adBlockEnabled,
      );
      final previousIds = _knownArticleIds.toSet();
      _itemsByFeed[feed.id] = refreshed.items;
      final newItems = refreshed.items
          .where((item) => !previousIds.contains(item.id))
          .toList();

      _knownArticleIds.addAll(refreshed.items.map((item) => item.id));
      if (!isInitial) {
        _unreadArticleIds.addAll(newItems.map((item) => item.id));
      }
      _rebuildKnownIds();

      if (triggerNotifications &&
          _settings.notificationsEnabled &&
          newItems.isNotEmpty &&
          notificationAccess == NotificationAccess.granted) {
        for (final item in newItems.take(3)) {
          _browserBridge.showNotification(
            title: item.feedTitle,
            body: item.title,
            iconUrl: item.imageUrl,
          );
        }
      }

      newItemsAccumulator.addAll(newItems);
      return feed.copyWith(
        title: refreshed.resolvedTitle,
        cachedArticleCount: refreshed.items.length,
        lastFetchedAt: refreshed.fetchedAt,
        clearLastError: true,
      );
    } catch (error) {
      return feed.copyWith(
        lastFetchedAt: DateTime.now(),
        lastError: error.toString(),
      );
    }
  }

  void _startAutoRefresh() {
    _refreshTicker?.cancel();
    _refreshTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(_runAutoRefreshTick());
    });
  }

  Future<void> _runAutoRefreshTick() async {
    if (!_settings.autoRefreshEnabled || _isRefreshing) {
      return;
    }
    final now = DateTime.now();
    final dueFeedIds = _feeds
        .where((feed) {
          if (!feed.enabled) {
            return false;
          }
          final lastFetchedAt = feed.lastFetchedAt;
          if (lastFetchedAt == null) {
            return true;
          }
          return now.difference(lastFetchedAt) >= feed.refreshInterval;
        })
        .map((feed) => feed.id)
        .toSet();
    if (dueFeedIds.isEmpty) {
      return;
    }

    _isRefreshing = true;
    notifyListeners();
    final updatedFeeds = <FeedSource>[];
    final allNewItems = <NewsItem>[];
    for (final feed in _feeds) {
      if (dueFeedIds.contains(feed.id)) {
        updatedFeeds.add(
          await _refreshSingleFeed(
            feed,
            isInitial: false,
            triggerNotifications: true,
            newItemsAccumulator: allNewItems,
          ),
        );
      } else {
        updatedFeeds.add(feed);
      }
    }
    _feeds = updatedFeeds;
    _isRefreshing = false;
    _lastRefreshAt = now;
    _lastStatus = allNewItems.isEmpty
        ? 'Auto refresh hoàn tất.'
        : 'Auto refresh có ${allNewItems.length} tin mới.';
    _syncBadge();
    await _persist();
    notifyListeners();
  }

  PersistedState _buildPersistedState() {
    return PersistedState(
      feeds: _feeds,
      settings: _settings,
      knownArticleIds: _knownArticleIds.toList(),
      unreadArticleIds: _unreadArticleIds.toList(),
      cachedArticlesByFeed: _itemsByFeed.map(
        (feedId, items) => MapEntry(feedId, List<NewsItem>.from(items)),
      ),
    );
  }

  void _rebuildKnownIds() {
    final retained = <String>{..._unreadArticleIds};
    final items = _itemsByFeed.values.expand((feedItems) => feedItems).toList()
      ..sort((left, right) => right.publishedAt.compareTo(left.publishedAt));
    for (final item in items) {
      retained.add(item.id);
      if (retained.length >= _maxKnownIds) {
        break;
      }
    }
    _knownArticleIds
      ..clear()
      ..addAll(retained);
    _unreadArticleIds.removeWhere((id) => !_knownArticleIds.contains(id));
  }

  void _syncBadge() {
    _browserBridge.syncUnreadBadge(
      count: unreadCount,
      appTitle: 'RSS News Hub',
    );
  }

  String _createFeedId(String url) {
    final raw = '${DateTime.now().microsecondsSinceEpoch}|$url';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }

  Future<void> _persist() {
    return _storageService.save(_buildPersistedState());
  }

  @override
  void dispose() {
    _refreshTicker?.cancel();
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
