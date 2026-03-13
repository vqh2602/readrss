import 'dart:async';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

import '../models.dart';

class RssService {
  RssService({http.Client? client}) : _client = client ?? http.Client();

  static const _maxItemsPerFeed = 30;
  static const _requestTimeout = Duration(seconds: 14);
  static final _rfc822Formats = <DateFormat>[
    DateFormat('EEE, dd MMM yyyy HH:mm:ss Z', 'en_US'),
    DateFormat('EEE, dd MMM yyyy HH:mm Z', 'en_US'),
    DateFormat('dd MMM yyyy HH:mm:ss Z', 'en_US'),
    DateFormat('dd MMM yyyy HH:mm Z', 'en_US'),
  ];
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
    final xml = await _downloadFeed(normalizedUri);
    return _parseFeed(xml: xml, source: source, adBlockEnabled: adBlockEnabled);
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

  Future<String> _downloadFeed(Uri source) async {
    Object? lastError;
    for (final target in _buildFetchTargets(source)) {
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
        lastError = StateError('HTTP ${response.statusCode}');
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('Khong tai duoc RSS: $lastError');
  }

  List<Uri> _buildFetchTargets(Uri source) {
    final encoded = Uri.encodeComponent(source.toString());
    return <Uri>[
      source,
      Uri.parse('https://api.allorigins.win/raw?url=$encoded'),
      Uri.parse('https://api.codetabs.com/v1/proxy?quest=$encoded'),
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

    return FeedRefreshResult(
      source: source,
      resolvedTitle: resolvedTitle.trim().isEmpty
          ? source.title
          : resolvedTitle,
      items: items.take(_maxItemsPerFeed).toList(),
      fetchedAt: DateTime.now(),
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

    return FeedRefreshResult(
      source: source,
      resolvedTitle: resolvedTitle.trim().isEmpty
          ? source.title
          : resolvedTitle,
      items: items.take(_maxItemsPerFeed).toList(),
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

    return fragment.text
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
}
