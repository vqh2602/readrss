import 'dart:convert';

import 'package:flutter/material.dart';

enum FeedDisplayMode {
  cards,
  spotlight,
  headlines;

  String get label => switch (this) {
    FeedDisplayMode.cards => 'Danh sach',
    FeedDisplayMode.spotlight => 'Focus',
    FeedDisplayMode.headlines => 'Tieu de',
  };

  static FeedDisplayMode fromStorage(String? value) {
    return FeedDisplayMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => FeedDisplayMode.cards,
    );
  }
}

class FeedSource {
  const FeedSource({
    required this.id,
    required this.title,
    required this.url,
    required this.refreshInterval,
    this.lastFetchedAt,
    this.lastError,
    this.enabled = true,
  });

  final String id;
  final String title;
  final String url;
  final Duration refreshInterval;
  final DateTime? lastFetchedAt;
  final String? lastError;
  final bool enabled;

  FeedSource copyWith({
    String? title,
    String? url,
    Duration? refreshInterval,
    DateTime? lastFetchedAt,
    String? lastError,
    bool clearLastError = false,
    bool? enabled,
  }) {
    return FeedSource(
      id: id,
      title: title ?? this.title,
      url: url ?? this.url,
      refreshInterval: refreshInterval ?? this.refreshInterval,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'url': url,
      'refreshIntervalMinutes': refreshInterval.inMinutes,
      'lastFetchedAt': lastFetchedAt?.toIso8601String(),
      'lastError': lastError,
      'enabled': enabled,
    };
  }

  static FeedSource fromJson(Map<String, dynamic> json) {
    return FeedSource(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
      refreshInterval: Duration(
        minutes: (json['refreshIntervalMinutes'] as num?)?.toInt() ?? 15,
      ),
      lastFetchedAt: json['lastFetchedAt'] == null
          ? null
          : DateTime.tryParse(json['lastFetchedAt'] as String),
      lastError: json['lastError'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

class NewsItem {
  const NewsItem({
    required this.id,
    required this.feedId,
    required this.feedTitle,
    required this.title,
    required this.link,
    required this.publishedAt,
    required this.summary,
    required this.content,
    this.author,
    this.imageUrl,
  });

  final String id;
  final String feedId;
  final String feedTitle;
  final String title;
  final String link;
  final DateTime publishedAt;
  final String summary;
  final String content;
  final String? author;
  final String? imageUrl;

  String get teaser {
    final value = summary.isNotEmpty ? summary : content;
    if (value.length <= 220) {
      return value;
    }
    return '${value.substring(0, 220).trimRight()}...';
  }

  static String createId({
    required String feedId,
    required String guid,
    required String link,
    required String title,
    required DateTime publishedAt,
  }) {
    final raw = '$feedId|$guid|$link|$title|${publishedAt.toIso8601String()}';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '');
  }
}

class ReaderSettings {
  const ReaderSettings({
    this.themeMode = ThemeMode.system,
    this.displayMode = FeedDisplayMode.cards,
    this.notificationsEnabled = false,
    this.adBlockEnabled = true,
    this.autoRefreshEnabled = true,
  });

  final ThemeMode themeMode;
  final FeedDisplayMode displayMode;
  final bool notificationsEnabled;
  final bool adBlockEnabled;
  final bool autoRefreshEnabled;

  ReaderSettings copyWith({
    ThemeMode? themeMode,
    FeedDisplayMode? displayMode,
    bool? notificationsEnabled,
    bool? adBlockEnabled,
    bool? autoRefreshEnabled,
  }) {
    return ReaderSettings(
      themeMode: themeMode ?? this.themeMode,
      displayMode: displayMode ?? this.displayMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      adBlockEnabled: adBlockEnabled ?? this.adBlockEnabled,
      autoRefreshEnabled: autoRefreshEnabled ?? this.autoRefreshEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'themeMode': themeMode.name,
      'displayMode': displayMode.name,
      'notificationsEnabled': notificationsEnabled,
      'adBlockEnabled': adBlockEnabled,
      'autoRefreshEnabled': autoRefreshEnabled,
    };
  }

  static ReaderSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ReaderSettings();
    }
    return ReaderSettings(
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      displayMode: FeedDisplayMode.fromStorage(json['displayMode'] as String?),
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      adBlockEnabled: json['adBlockEnabled'] as bool? ?? true,
      autoRefreshEnabled: json['autoRefreshEnabled'] as bool? ?? true,
    );
  }
}

class PersistedState {
  const PersistedState({
    required this.feeds,
    required this.settings,
    required this.knownArticleIds,
    required this.unreadArticleIds,
  });

  final List<FeedSource> feeds;
  final ReaderSettings settings;
  final List<String> knownArticleIds;
  final List<String> unreadArticleIds;

  factory PersistedState.initial() {
    return const PersistedState(
      feeds: <FeedSource>[],
      settings: ReaderSettings(),
      knownArticleIds: <String>[],
      unreadArticleIds: <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'feeds': feeds.map((feed) => feed.toJson()).toList(),
      'settings': settings.toJson(),
      'knownArticleIds': knownArticleIds,
      'unreadArticleIds': unreadArticleIds,
    };
  }

  static PersistedState fromJson(Map<String, dynamic> json) {
    final feedList = (json['feeds'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => FeedSource.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();
    return PersistedState(
      feeds: feedList,
      settings: ReaderSettings.fromJson(
        json['settings'] == null
            ? null
            : Map<String, dynamic>.from(
                json['settings'] as Map<dynamic, dynamic>,
              ),
      ),
      knownArticleIds:
          (json['knownArticleIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      unreadArticleIds:
          (json['unreadArticleIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
    );
  }
}

class BackupSnapshot {
  const BackupSnapshot({
    required this.version,
    required this.exportedAt,
    required this.feeds,
    required this.settings,
  });

  final int version;
  final DateTime exportedAt;
  final List<FeedSource> feeds;
  final ReaderSettings settings;

  factory BackupSnapshot.fromPersisted(PersistedState state) {
    return BackupSnapshot(
      version: 1,
      exportedAt: DateTime.now(),
      feeds: state.feeds,
      settings: state.settings,
    );
  }

  PersistedState toPersistedState() {
    return PersistedState(
      feeds: feeds,
      settings: settings,
      knownArticleIds: const <String>[],
      unreadArticleIds: const <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'feeds': feeds.map((feed) => feed.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }

  static BackupSnapshot fromJson(Map<String, dynamic> json) {
    final feedList = (json['feeds'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => FeedSource.fromJson(
            Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          ),
        )
        .toList();
    return BackupSnapshot(
      version: (json['version'] as num?)?.toInt() ?? 1,
      exportedAt:
          DateTime.tryParse(json['exportedAt'] as String? ?? '') ??
          DateTime.now(),
      feeds: feedList,
      settings: ReaderSettings.fromJson(
        json['settings'] == null
            ? null
            : Map<String, dynamic>.from(
                json['settings'] as Map<dynamic, dynamic>,
              ),
      ),
    );
  }
}

class FeedPreview {
  const FeedPreview({
    required this.title,
    required this.items,
    required this.fetchedAt,
  });

  final String title;
  final List<NewsItem> items;
  final DateTime fetchedAt;
}

class FeedRefreshResult {
  const FeedRefreshResult({
    required this.source,
    required this.resolvedTitle,
    required this.items,
    required this.fetchedAt,
  });

  final FeedSource source;
  final String resolvedTitle;
  final List<NewsItem> items;
  final DateTime fetchedAt;
}
