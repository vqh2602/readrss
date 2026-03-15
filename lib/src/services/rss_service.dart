import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../models.dart';

class RssService {
  RssService({http.Client? client, String? gatewayBaseUrl})
    : _client = client ?? http.Client(),
      _gatewayBaseUri = _resolveGatewayBaseUri(gatewayBaseUrl);

  static const _requestTimeout = Duration(seconds: 14);
  static const _defaultGatewayUrl = 'https://readrss-gateway.onrender.com';
  static final _rfc822Formats = <DateFormat>[
    DateFormat('EEE, dd MMM yyyy HH:mm:ss', 'en_US'),
    DateFormat('EEE, dd MMM yyyy HH:mm', 'en_US'),
    DateFormat('dd MMM yyyy HH:mm:ss', 'en_US'),
    DateFormat('dd MMM yyyy HH:mm', 'en_US'),
  ];
  static final _rfc822WithZone = RegExp(
    r'^(?:[A-Za-z]{3,},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?(?:\s+([A-Za-z]+|(?:GMT|UTC)?[+\-]\d{1,2}(?::?\d{2})?))?$',
  );
  static const _monthNumbers = <String, int>{
    'JAN': 1,
    'FEB': 2,
    'MAR': 3,
    'APR': 4,
    'MAY': 5,
    'JUN': 6,
    'JUL': 7,
    'AUG': 8,
    'SEP': 9,
    'OCT': 10,
    'NOV': 11,
    'DEC': 12,
  };
  static const _timezoneOffsets = <String, Duration>{
    'UT': Duration.zero,
    'UTC': Duration.zero,
    'GMT': Duration.zero,
    'Z': Duration.zero,
    'EST': Duration(hours: -5),
    'EDT': Duration(hours: -4),
    'CST': Duration(hours: -6),
    'CDT': Duration(hours: -5),
    'MST': Duration(hours: -7),
    'MDT': Duration(hours: -6),
    'PST': Duration(hours: -8),
    'PDT': Duration(hours: -7),
    'JST': Duration(hours: 9),
    'KST': Duration(hours: 9),
    'ICT': Duration(hours: 7),
  };
  static final _adLikePattern = RegExp(
    r'(^|[\s_\-])(ad|ads|advert|advertisement|sponsor|promo|banner|popup)([\s_\-]|$)',
    caseSensitive: false,
  );
  static const _adHosts = <String>[
    'doubleclick',
    'googlesyndication',
    'adservice',
    'taboola',
    'outbrain',
  ];
  static final _hostLikePattern = RegExp(r'^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$');

  final http.Client _client;
  final Uri? _gatewayBaseUri;

  Future<FeedPreview> previewFeed(
    String rawUrl, {
    required bool adBlockEnabled,
  }) async {
    final source = FeedSource(
      id: 'preview',
      title: rawUrl,
      url: _normalizeUri(rawUrl).toString(),
      refreshInterval: const Duration(minutes: 15),
    );
    final result = await refreshFeed(source, adBlockEnabled: adBlockEnabled);
    return FeedPreview(
      title: result.resolvedTitle,
      items: result.items.take(5).toList(),
      fetchedAt: result.fetchedAt,
    );
  }

  Future<FeedRefreshResult> refreshFeed(
    FeedSource source, {
    required bool adBlockEnabled,
  }) async {
    final normalizedUri = _normalizeUri(source.url);
    final requestUri = _buildRequestUri(normalizedUri);
    try {
      final payload = await _downloadFeedXml(
        requestUri,
        sourceUri: normalizedUri,
      );
      final jsonFeedResult = _tryParseJsonFeedPayload(
        payload: payload,
        source: source,
        adBlockEnabled: adBlockEnabled,
      );
      if (jsonFeedResult != null) {
        return jsonFeedResult;
      }
      return _parseFeed(
        xml: payload,
        source: source,
        adBlockEnabled: adBlockEnabled,
      );
    } catch (error) {
      if (error is FeedLoadException) {
        rethrow;
      }
      throw FeedLoadException(_describeFetchError(error, normalizedUri));
    }
  }

  Uri _normalizeUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Địa chỉ RSS đang rỗng.');
    }
    final value =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority) {
      throw const FormatException('Địa chỉ RSS không hợp lệ.');
    }
    return uri;
  }

  Uri _buildRequestUri(Uri sourceUri) {
    final gateway = _gatewayBaseUri;
    if (gateway == null) {
      return sourceUri;
    }
    final basePath = gateway.path.endsWith('/')
        ? gateway.path.substring(0, gateway.path.length - 1)
        : gateway.path;
    final path = basePath.isEmpty ? '/api/rss' : '$basePath/api/rss';
    return gateway.replace(
      path: path,
      queryParameters: <String, String>{'url': sourceUri.toString()},
    );
  }

  Future<String> _downloadFeedXml(
    Uri requestUri, {
    required Uri sourceUri,
  }) async {
    try {
      // Keep request simple to avoid triggering CORS preflight in web.
      final response = await _client.get(requestUri).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FeedLoadException('HTTP ${response.statusCode} @ $sourceUri');
      }
      final body = response.body.trim();
      if (body.isEmpty) {
        throw FeedLoadException('Nguồn RSS trả về dữ liệu rỗng @ $sourceUri');
      }
      return body;
    } catch (error) {
      if (error is FeedLoadException) {
        rethrow;
      }
      throw FeedLoadException('$error @ $sourceUri');
    }
  }

  String _describeFetchError(Object error, Uri source) {
    final message = error.toString();
    final gateway = _gatewayBaseUri;
    if (gateway != null) {
      if (message.toLowerCase().contains('connection refused') ||
          message.toLowerCase().contains('failed host lookup')) {
        return 'Không kết nối được RSS gateway $gateway. Hãy chạy: dart run tool/rss_gateway.dart --port ${gateway.port == 0 ? 8787 : gateway.port}';
      }
      return 'Không tải được RSS qua gateway $gateway cho nguồn $source. Chi tiết: $message';
    }
    final normalized = message.toLowerCase();
    if (normalized.contains('xmlhttprequest error') ||
        normalized.contains('failed to fetch') ||
        normalized.contains('cors')) {
      return 'Nguồn RSS đang chặn CORS khi đọc trực tiếp trên trình duyệt: $source';
    }
    return 'Không tải được RSS trực tiếp từ nguồn gốc. Chi tiết: $message';
  }

  static Uri? _parseGatewayBaseUri(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.trim().isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  static Uri? _resolveGatewayBaseUri(String? gatewayBaseUrl) {
    final explicit = gatewayBaseUrl?.trim() ?? '';
    if (explicit.isNotEmpty) {
      return _parseGatewayBaseUri(explicit);
    }

    final defined = const String.fromEnvironment('RSS_GATEWAY_URL').trim();
    if (defined.isNotEmpty) {
      return _parseGatewayBaseUri(defined);
    }

    if (kIsWeb) {
      return _parseGatewayBaseUri(_defaultGatewayUrl);
    }
    return null;
  }

  FeedRefreshResult _parseFeed({
    required String xml,
    required FeedSource source,
    required bool adBlockEnabled,
  }) {
    final document = XmlDocument.parse(xml);
    final root = document.rootElement;
    if (root.name.local == 'feed') {
      return _parseAtom(root, source: source, adBlockEnabled: adBlockEnabled);
    }

    final channel = _firstChild(root, 'channel') ?? root;
    final resolvedTitle =
        _readText(_firstChild(channel, 'title')) ?? source.title;
    final items =
        _children(channel, 'item')
            .map(
              (item) => _parseRssItem(
                item,
                source: source,
                feedTitle: resolvedTitle,
                adBlockEnabled: adBlockEnabled,
              ),
            )
            .whereType<NewsItem>()
            .toList()
          ..sort(
            (left, right) => right.publishedAt.compareTo(left.publishedAt),
          );

    return _finalizeFeedResult(
      source: source,
      resolvedTitle: resolvedTitle.trim().isEmpty
          ? source.title
          : resolvedTitle,
      items: items,
    );
  }

  FeedRefreshResult? _tryParseJsonFeedPayload({
    required String payload,
    required FeedSource source,
    required bool adBlockEnabled,
  }) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty ||
        (!trimmed.startsWith('{') && !trimmed.startsWith('['))) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final version = decoded['version']?.toString().toLowerCase() ?? '';
      final isJsonFeed =
          version.contains('jsonfeed.org/version') ||
          decoded.containsKey('items');
      if (!isJsonFeed) {
        return null;
      }
      return _parseJsonFeed(
        jsonFeed: decoded,
        source: source,
        adBlockEnabled: adBlockEnabled,
      );
    } catch (_) {
      return null;
    }
  }

  FeedRefreshResult _parseJsonFeed({
    required Map<String, dynamic> jsonFeed,
    required FeedSource source,
    required bool adBlockEnabled,
  }) {
    final resolvedTitle =
        jsonFeed['title']?.toString().trim().isNotEmpty == true
        ? jsonFeed['title'].toString().trim()
        : source.title;
    final itemsJson = jsonFeed['items'] as List<dynamic>? ?? const <dynamic>[];
    final items =
        itemsJson
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => _parseJsonFeedItem(
                Map<String, dynamic>.from(item),
                source: source,
                feedTitle: resolvedTitle,
                adBlockEnabled: adBlockEnabled,
              ),
            )
            .whereType<NewsItem>()
            .toList()
          ..sort(
            (left, right) => right.publishedAt.compareTo(left.publishedAt),
          );

    return _finalizeFeedResult(
      source: source,
      resolvedTitle: resolvedTitle,
      items: items,
    );
  }

  FeedRefreshResult _parseAtom(
    XmlElement root, {
    required FeedSource source,
    required bool adBlockEnabled,
  }) {
    final resolvedTitle = _readText(_firstChild(root, 'title')) ?? source.title;
    final items =
        _children(root, 'entry')
            .map(
              (entry) => _parseAtomEntry(
                entry,
                source: source,
                feedTitle: resolvedTitle,
                adBlockEnabled: adBlockEnabled,
              ),
            )
            .whereType<NewsItem>()
            .toList()
          ..sort(
            (left, right) => right.publishedAt.compareTo(left.publishedAt),
          );

    return _finalizeFeedResult(
      source: source,
      resolvedTitle: resolvedTitle.trim().isEmpty
          ? source.title
          : resolvedTitle,
      items: items,
    );
  }

  FeedRefreshResult _finalizeFeedResult({
    required FeedSource source,
    required String resolvedTitle,
    required List<NewsItem> items,
  }) {
    if (items.isEmpty) {
      throw const FeedLoadException('Nguồn RSS không trả về bài viết nào.');
    }
    return FeedRefreshResult(
      source: source,
      resolvedTitle: resolvedTitle,
      items: List<NewsItem>.from(items),
      fetchedAt: DateTime.now(),
    );
  }

  NewsItem? _parseRssItem(
    XmlElement item, {
    required FeedSource source,
    required String feedTitle,
    required bool adBlockEnabled,
  }) {
    final title = _readText(_firstChild(item, 'title')) ?? 'Không có tiêu đề';
    final linkNode = _firstChild(item, 'link');
    final guidNode = _firstChild(item, 'guid');
    final linkText = _readText(linkNode);
    final guidText = _readText(guidNode);
    final descriptionHtml = _readText(_firstChild(item, 'description')) ?? '';
    final contentHtml =
        _readText(_firstChild(item, 'encoded')) ??
        _readText(_firstChild(item, 'content')) ??
        descriptionHtml;
    final link = _resolveArticleLink(
      sourceUrl: source.url,
      candidates: <String?>[
        linkText,
        _resolveGuidPermalinkCandidate(guidNode, guidText),
        _extractFirstAnchorHref(descriptionHtml),
        _extractFirstAnchorHref(contentHtml),
      ],
    );
    final guid = guidText?.trim().isNotEmpty == true ? guidText!.trim() : link;
    final publishedAt =
        _parseDate(
          _readText(_firstChild(item, 'pubDate')) ??
              _readText(_firstChild(item, 'date')) ??
              _readText(_firstChild(item, 'published')),
        ) ??
        DateTime.now();

    return NewsItem(
      id: NewsItem.createId(
        feedId: source.id,
        guid: guid,
        link: link,
        title: title,
        publishedAt: publishedAt,
      ),
      feedId: source.id,
      feedTitle: feedTitle,
      title: title.trim(),
      link: link.trim(),
      publishedAt: publishedAt,
      summary: _sanitizeHtml(descriptionHtml, adBlockEnabled: adBlockEnabled),
      content: _sanitizeHtml(contentHtml, adBlockEnabled: adBlockEnabled),
      author:
          _readText(_firstChild(item, 'creator')) ??
          _readText(_firstChild(item, 'author')),
      imageUrl: _extractImageUrl(item, descriptionHtml, contentHtml),
    );
  }

  NewsItem? _parseAtomEntry(
    XmlElement item, {
    required FeedSource source,
    required String feedTitle,
    required bool adBlockEnabled,
  }) {
    final title = _readText(_firstChild(item, 'title')) ?? 'Không có tiêu đề';
    final linkText = _resolveAtomLink(item);
    final idText = _readText(_firstChild(item, 'id'));
    final summaryHtml = _readText(_firstChild(item, 'summary')) ?? '';
    final contentHtml = _readText(_firstChild(item, 'content')) ?? summaryHtml;
    final link = _resolveArticleLink(
      sourceUrl: source.url,
      candidates: <String?>[
        linkText,
        idText,
        _extractFirstAnchorHref(summaryHtml),
        _extractFirstAnchorHref(contentHtml),
      ],
    );
    final guid = idText?.trim().isNotEmpty == true ? idText!.trim() : link;
    final publishedAt =
        _parseDate(
          _readText(_firstChild(item, 'updated')) ??
              _readText(_firstChild(item, 'published')),
        ) ??
        DateTime.now();
    final authorNode = _firstChild(item, 'author');
    final author = authorNode == null
        ? null
        : (_readText(_firstChild(authorNode, 'name')) ?? _readText(authorNode));

    return NewsItem(
      id: NewsItem.createId(
        feedId: source.id,
        guid: guid,
        link: link,
        title: title,
        publishedAt: publishedAt,
      ),
      feedId: source.id,
      feedTitle: feedTitle,
      title: title.trim(),
      link: link.trim(),
      publishedAt: publishedAt,
      summary: _sanitizeHtml(summaryHtml, adBlockEnabled: adBlockEnabled),
      content: _sanitizeHtml(contentHtml, adBlockEnabled: adBlockEnabled),
      author: author,
      imageUrl: _extractImageUrl(item, summaryHtml, contentHtml),
    );
  }

  NewsItem? _parseJsonFeedItem(
    Map<String, dynamic> item, {
    required FeedSource source,
    required String feedTitle,
    required bool adBlockEnabled,
  }) {
    final title = item['title']?.toString().trim().isNotEmpty == true
        ? item['title'].toString().trim()
        : 'Không có tiêu đề';
    final linkText = item['url']?.toString().trim().isNotEmpty == true
        ? item['url'].toString().trim()
        : (item['external_url']?.toString().trim().isNotEmpty == true
              ? item['external_url'].toString().trim()
              : null);
    final idText = item['id']?.toString();

    final contentHtml = item['content_html']?.toString() ?? '';
    final contentText = item['content_text']?.toString() ?? '';
    final summaryHtml = contentHtml.isNotEmpty ? contentHtml : contentText;
    final link = _resolveArticleLink(
      sourceUrl: source.url,
      candidates: <String?>[
        linkText,
        idText,
        _extractFirstAnchorHref(contentHtml),
        _extractFirstAnchorHref(contentText),
      ],
    );
    final publishedAt =
        _parseDate(item['date_published']?.toString()) ??
        _parseDate(item['date_modified']?.toString()) ??
        DateTime.now();
    final imageUrl = item['image']?.toString().trim().isNotEmpty == true
        ? item['image'].toString().trim()
        : _extractJsonFeedAttachmentImage(item);

    return NewsItem(
      id: NewsItem.createId(
        feedId: source.id,
        guid: idText?.trim().isNotEmpty == true ? idText!.trim() : link,
        link: link,
        title: title,
        publishedAt: publishedAt,
      ),
      feedId: source.id,
      feedTitle: feedTitle,
      title: title,
      link: link,
      publishedAt: publishedAt,
      summary: _sanitizeHtml(summaryHtml, adBlockEnabled: adBlockEnabled),
      content: _sanitizeHtml(
        contentHtml.isNotEmpty ? contentHtml : contentText,
        adBlockEnabled: adBlockEnabled,
      ),
      author: _extractJsonFeedAuthor(item),
      imageUrl: imageUrl,
    );
  }

  Iterable<XmlElement> _children(XmlElement element, String localName) {
    return element.children.whereType<XmlElement>().where(
      (child) => child.name.local == localName,
    );
  }

  XmlElement? _firstChild(XmlElement element, String localName) {
    for (final child in _children(element, localName)) {
      return child;
    }
    return null;
  }

  String? _readText(XmlElement? element) {
    if (element == null) {
      return null;
    }
    return element.innerText.trim();
  }

  String? _resolveAtomLink(XmlElement entry) {
    String? fallback;
    for (final link in _children(entry, 'link')) {
      final href = link.getAttribute('href');
      if (href == null || href.trim().isEmpty) {
        continue;
      }
      final rel = link.getAttribute('rel');
      if (rel == null || rel == 'alternate') {
        return href;
      }
      fallback ??= href;
    }
    return fallback;
  }

  String _resolveArticleLink({
    required String sourceUrl,
    required List<String?> candidates,
  }) {
    final baseUri = Uri.tryParse(sourceUrl);
    for (final candidate in candidates) {
      final normalized = _normalizeArticleUrlCandidate(
        rawCandidate: candidate,
        baseUri: baseUri,
      );
      if (normalized != null) {
        return normalized;
      }
    }
    return _normalizeArticleUrlCandidate(
          rawCandidate: sourceUrl,
          baseUri: null,
        ) ??
        sourceUrl.trim();
  }

  String? _normalizeArticleUrlCandidate({
    required String? rawCandidate,
    required Uri? baseUri,
  }) {
    final trimmed = rawCandidate?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.startsWith('#')) {
      return null;
    }

    Uri? uri = Uri.tryParse(trimmed);
    uri ??= Uri.tryParse(Uri.encodeFull(trimmed));
    if (uri == null) {
      return null;
    }

    if (!uri.hasScheme) {
      final hostCandidate = _extractHostCandidate(trimmed);
      if (trimmed.startsWith('//')) {
        final scheme = _safeHttpScheme(baseUri?.scheme) ?? 'https';
        final absolute = '$scheme:$trimmed';
        uri = Uri.tryParse(absolute) ?? Uri.tryParse(Uri.encodeFull(absolute));
      } else if (hostCandidate != null) {
        final absolute = 'https://$trimmed';
        uri = Uri.tryParse(absolute) ?? Uri.tryParse(Uri.encodeFull(absolute));
      } else if (baseUri != null && baseUri.hasAuthority) {
        uri = baseUri.resolveUri(uri);
      } else {
        return null;
      }
    }

    if (uri == null || uri.host.trim().isEmpty) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    return uri.toString();
  }

  String? _extractFirstAnchorHref(String rawHtml) {
    if (rawHtml.trim().isEmpty || !rawHtml.contains('<a')) {
      return null;
    }
    final fragment = html_parser.parseFragment(rawHtml);
    return fragment.querySelector('a[href]')?.attributes['href']?.trim();
  }

  String? _resolveGuidPermalinkCandidate(
    XmlElement? guidNode,
    String? guidText,
  ) {
    final value = guidText?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final isPermalinkAttr = guidNode
        ?.getAttribute('isPermaLink')
        ?.trim()
        .toLowerCase();
    if (isPermalinkAttr == 'false') {
      // Some feeds still use URL with isPermaLink=false; keep it only if absolute.
      final parsed = Uri.tryParse(value);
      if (parsed == null || !parsed.hasAbsolutePath || !parsed.hasScheme) {
        return null;
      }
      final scheme = parsed.scheme.toLowerCase();
      return scheme == 'http' || scheme == 'https' ? value : null;
    }
    return value;
  }

  String? _extractHostCandidate(String value) {
    if (value.startsWith('/') ||
        value.startsWith('.') ||
        value.startsWith('?')) {
      return null;
    }
    final firstSegment = value.split(RegExp(r'[/?#]')).first;
    if (_hostLikePattern.hasMatch(firstSegment)) {
      return firstSegment;
    }
    return null;
  }

  String? _safeHttpScheme(String? rawScheme) {
    if (rawScheme == null) {
      return null;
    }
    final normalized = rawScheme.toLowerCase();
    return normalized == 'http' || normalized == 'https' ? normalized : null;
  }

  DateTime? _parseDate(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) {
      if (!iso.isUtc && !_containsTimezoneDesignator(value)) {
        return DateTime.utc(
          iso.year,
          iso.month,
          iso.day,
          iso.hour,
          iso.minute,
          iso.second,
          iso.millisecond,
          iso.microsecond,
        ).toLocal();
      }
      return iso.toLocal();
    }

    final rfc822Match = _rfc822WithZone.firstMatch(
      value.replaceAll(RegExp(r'\s+'), ' '),
    );
    if (rfc822Match != null) {
      final parsed = _parseStructuredRfc822(rfc822Match);
      if (parsed != null) {
        return parsed.toLocal();
      }
    }

    for (final format in _rfc822Formats) {
      try {
        return format.parseUtc(value).toLocal();
      } catch (_) {
        // Try next pattern.
      }
    }

    final cleaned = value.replaceFirst(RegExp(r'^[A-Za-z]{3,},\s*'), '');
    for (final format in <DateFormat>[
      DateFormat('dd MMM yyyy HH:mm:ss', 'en_US'),
      DateFormat('dd MMM yyyy HH:mm', 'en_US'),
    ]) {
      try {
        return format.parseUtc(cleaned).toLocal();
      } catch (_) {
        // Try next pattern.
      }
    }
    return null;
  }

  DateTime? _parseStructuredRfc822(RegExpMatch match) {
    final day = int.tryParse(match.group(1) ?? '');
    final month = _monthNumbers[(match.group(2) ?? '').toUpperCase()];
    final year = int.tryParse(match.group(3) ?? '');
    final hour = int.tryParse(match.group(4) ?? '');
    final minute = int.tryParse(match.group(5) ?? '');
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;
    if (day == null ||
        month == null ||
        year == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    final zone = match.group(7)?.trim();
    if (zone == null || zone.isEmpty) {
      return DateTime.utc(year, month, day, hour, minute, second).toLocal();
    }

    final offset = _parseTimeZoneOffset(zone);
    if (offset == null) {
      return DateTime.utc(year, month, day, hour, minute, second).toLocal();
    }

    return DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
    ).subtract(offset);
  }

  Duration? _parseTimeZoneOffset(String rawZone) {
    final zone = rawZone.toUpperCase();
    final knownOffset = _timezoneOffsets[zone];
    if (knownOffset != null) {
      return knownOffset;
    }

    final normalized = zone.startsWith('GMT') || zone.startsWith('UTC')
        ? zone.substring(3)
        : zone;
    if (normalized.isEmpty) {
      return Duration.zero;
    }

    final match = RegExp(
      r'^([+\-])(\d{1,2})(?::?(\d{2}))?$',
    ).firstMatch(normalized);
    if (match == null) {
      return null;
    }

    final sign = match.group(1) == '-' ? -1 : 1;
    final hours = int.tryParse(match.group(2) ?? '');
    final minutes = int.tryParse(match.group(3) ?? '0') ?? 0;
    if (hours == null) {
      return null;
    }
    return Duration(hours: hours * sign, minutes: minutes * sign);
  }

  bool _containsTimezoneDesignator(String value) {
    final normalized = value.toUpperCase();
    return normalized.contains('Z') ||
        normalized.contains(' GMT') ||
        normalized.contains(' UTC') ||
        RegExp(r'([+\-]\d{2}:?\d{2})$').hasMatch(normalized);
  }

  String _sanitizeHtml(String rawValue, {required bool adBlockEnabled}) {
    final fragment = html_parser.parseFragment(rawValue);
    for (final selector in <String>['script', 'style', 'iframe', 'noscript']) {
      for (final element in fragment.querySelectorAll(selector)) {
        element.remove();
      }
    }
    for (final element in fragment.querySelectorAll('br')) {
      element.replaceWith(dom.Text('\n'));
    }
    if (adBlockEnabled) {
      for (final element in fragment.querySelectorAll('*').toList()) {
        final marker = [
          element.localName,
          element.id,
          element.className,
          ...element.attributes.values,
        ].join(' ');
        final source =
            (element.attributes['src'] ?? element.attributes['href'] ?? '');
        if (_adLikePattern.hasMatch(marker) ||
            _adHosts.any((host) => source.contains(host))) {
          element.remove();
        }
      }
    }

    final text = fragment.text ?? '';
    return text
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String? _extractImageUrl(
    XmlElement item,
    String descriptionHtml,
    String contentHtml,
  ) {
    for (final enclosure in _children(item, 'enclosure')) {
      final type = enclosure.getAttribute('type') ?? '';
      final url = enclosure.getAttribute('url');
      if (url != null && type.startsWith('image/')) {
        return url;
      }
    }
    for (final element in item.children.whereType<XmlElement>()) {
      if (element.name.local == 'thumbnail' ||
          element.name.local == 'content') {
        final mediaUrl = element.getAttribute('url');
        if (mediaUrl != null && mediaUrl.trim().isNotEmpty) {
          return mediaUrl.trim();
        }
      }
    }
    for (final rawHtml in <String>[contentHtml, descriptionHtml]) {
      if (rawHtml.trim().isEmpty) {
        continue;
      }
      final fragment = html_parser.parseFragment(rawHtml);
      final image = fragment.querySelector('img');
      final url = image?.attributes['src'] ?? image?.attributes['data-src'];
      if (url != null && url.trim().isNotEmpty) {
        return url.trim();
      }
    }
    return null;
  }

  String? _extractJsonFeedAttachmentImage(Map<String, dynamic> item) {
    final attachments =
        item['attachments'] as List<dynamic>? ?? const <dynamic>[];
    for (final attachment in attachments) {
      if (attachment is! Map<dynamic, dynamic>) {
        continue;
      }
      final map = Map<String, dynamic>.from(attachment);
      final url = map['url']?.toString().trim();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
  }

  String? _extractJsonFeedAuthor(Map<String, dynamic> item) {
    final authors = item['authors'] as List<dynamic>? ?? const <dynamic>[];
    for (final author in authors) {
      if (author is! Map<dynamic, dynamic>) {
        continue;
      }
      final map = Map<String, dynamic>.from(author);
      final name = map['name']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    final singleAuthor = item['author']?.toString().trim();
    if (singleAuthor != null && singleAuthor.isNotEmpty) {
      return singleAuthor;
    }
    return null;
  }
}

class FeedLoadException implements Exception {
  const FeedLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
