import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../models.dart';

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();

  static const _maxItemsPerFeed = 80;
  static const _requestTimeout = Duration(seconds: 14);
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

  final http.Client _client;

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
    try {
      final xml = await _downloadFeedXml(normalizedUri);
      return _parseFeed(
        xml: xml,
        source: source,
        adBlockEnabled: adBlockEnabled,
      );
    } catch (xmlError) {
      try {
        final jsonResponse = await _downloadFeedAsJson(normalizedUri);
        return _parseRss2Json(
          jsonResponse: jsonResponse,
          source: source,
          adBlockEnabled: adBlockEnabled,
        );
      } catch (jsonError) {
        throw FeedLoadException(
          'Khong tai duoc RSS. Web debug thuong bi chan boi CORS. '
          'Chi tiet XML: $xmlError | Chi tiet JSON fallback: $jsonError',
        );
      }
    }
  }

  Uri _normalizeUri(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Dia chi RSS dang rong.');
    }
    final value =
        trimmed.startsWith('http://') || trimmed.startsWith('https://')
        ? trimmed
        : 'https://$trimmed';
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasAuthority) {
      throw const FormatException('Dia chi RSS khong hop le.');
    }
    return uri;
  }

  Future<String> _downloadFeedXml(Uri source) async {
    Object? lastError;
    for (final target in _buildXmlFetchTargets(source)) {
      try {
        final response = await _client
            .get(
              target,
              headers: const <String, String>{
                'accept':
                    'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
                'cache-control': 'no-cache',
              },
            )
            .timeout(_requestTimeout);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            response.body.trim().isNotEmpty) {
          return response.body;
        }
        lastError = 'HTTP ${response.statusCode} @ $target';
      } catch (error) {
        lastError = '$error @ $target';
      }
    }
    throw FeedLoadException('$lastError');
  }

  Future<Map<String, dynamic>> _downloadFeedAsJson(Uri source) async {
    final target = Uri.parse(
      'https://api.rss2json.com/v1/api.json?rss_url=${Uri.encodeComponent(source.toString())}',
    );
    try {
      final response = await _client.get(target).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FeedLoadException('HTTP ${response.statusCode} @ $target');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FeedLoadException('rss2json tra ve du lieu khong hop le.');
      }
      return decoded;
    } catch (error) {
      if (error is FeedLoadException) {
        rethrow;
      }
      throw FeedLoadException('$error @ $target');
    }
  }

  List<Uri> _buildXmlFetchTargets(Uri source) {
    final encoded = Uri.encodeComponent(source.toString());
    return <Uri>[
      source,
      Uri.parse('https://api.allorigins.win/raw?url=$encoded'),
      Uri.parse('https://api.codetabs.com/v1/proxy/?quest=$encoded'),
    ];
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

  FeedRefreshResult _parseRss2Json({
    required Map<String, dynamic> jsonResponse,
    required FeedSource source,
    required bool adBlockEnabled,
  }) {
    final status = jsonResponse['status']?.toString().toLowerCase();
    if (status != 'ok') {
      final message =
          jsonResponse['message']?.toString() ??
          jsonResponse['error']?.toString() ??
          'rss2json khong tra ve trang thai ok.';
      throw FeedLoadException(message);
    }

    final feedJson = jsonResponse['feed'];
    final resolvedTitle = feedJson is Map<String, dynamic>
        ? (feedJson['title']?.toString().trim().isNotEmpty == true
              ? feedJson['title'].toString().trim()
              : source.title)
        : source.title;

    final itemsJson =
        (jsonResponse['items'] as List<dynamic>? ?? const <dynamic>[]);
    final items =
        itemsJson
            .whereType<Map<dynamic, dynamic>>()
            .map(
              (item) => _parseRss2JsonItem(
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
    final trimmedItems = items.take(_maxItemsPerFeed).toList();
    if (trimmedItems.isEmpty) {
      throw const FeedLoadException(
        'Nguon RSS khong tra ve bai viet nao hoac proxy tra du lieu rong.',
      );
    }
    return FeedRefreshResult(
      source: source,
      resolvedTitle: resolvedTitle,
      items: trimmedItems,
      fetchedAt: DateTime.now(),
    );
  }

  NewsItem? _parseRssItem(
    XmlElement item, {
    required FeedSource source,
    required String feedTitle,
    required bool adBlockEnabled,
  }) {
    final title = _readText(_firstChild(item, 'title')) ?? 'Khong co tieu de';
    final link = _readText(_firstChild(item, 'link')) ?? source.url;
    final guid = _readText(_firstChild(item, 'guid')) ?? link;
    final descriptionHtml = _readText(_firstChild(item, 'description')) ?? '';
    final contentHtml =
        _readText(_firstChild(item, 'encoded')) ??
        _readText(_firstChild(item, 'content')) ??
        descriptionHtml;
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
    final title = _readText(_firstChild(item, 'title')) ?? 'Khong co tieu de';
    final link = _resolveAtomLink(item) ?? source.url;
    final guid = _readText(_firstChild(item, 'id')) ?? link;
    final summaryHtml = _readText(_firstChild(item, 'summary')) ?? '';
    final contentHtml = _readText(_firstChild(item, 'content')) ?? summaryHtml;
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

  NewsItem? _parseRss2JsonItem(
    Map<String, dynamic> item, {
    required FeedSource source,
    required String feedTitle,
    required bool adBlockEnabled,
  }) {
    final title = item['title']?.toString().trim();
    final link = item['link']?.toString().trim();
    if (title == null || title.isEmpty || link == null || link.isEmpty) {
      return null;
    }

    final descriptionHtml = item['description']?.toString() ?? '';
    final contentHtml = item['content']?.toString().trim().isNotEmpty == true
        ? item['content'].toString()
        : descriptionHtml;
    final publishedAt =
        _parseDate(item['pubDate']?.toString()) ??
        _parseDate(item['published']?.toString()) ??
        DateTime.now();
    final imageUrl = item['thumbnail']?.toString().trim().isNotEmpty == true
        ? item['thumbnail'].toString().trim()
        : _extractImageUrlFromHtml(contentHtml, descriptionHtml);

    return NewsItem(
      id: NewsItem.createId(
        feedId: source.id,
        guid: item['guid']?.toString() ?? item['id']?.toString() ?? link,
        link: link,
        title: title,
        publishedAt: publishedAt,
      ),
      feedId: source.id,
      feedTitle: feedTitle,
      title: title,
      link: link,
      publishedAt: publishedAt,
      summary: _sanitizeHtml(descriptionHtml, adBlockEnabled: adBlockEnabled),
      content: _sanitizeHtml(contentHtml, adBlockEnabled: adBlockEnabled),
      author: item['author']?.toString(),
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

  DateTime? _parseDate(String? rawValue) {
    final value = rawValue?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }

    final iso = DateTime.tryParse(value);
    if (iso != null) {
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
        return format.parseLoose(value);
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
        return format.parseLoose(cleaned);
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
      return DateTime(year, month, day, hour, minute, second);
    }

    final offset = _parseTimeZoneOffset(zone);
    if (offset == null) {
      return DateTime(year, month, day, hour, minute, second);
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

  String? _extractImageUrlFromHtml(String contentHtml, String descriptionHtml) {
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
}

class FeedLoadException implements Exception {
  const FeedLoadException(this.message);

  final String message;

  @override
  String toString() => message;
}
