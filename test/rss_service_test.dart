import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:readrss/src/models.dart';
import 'package:readrss/src/services/rss_service.dart';

void main() {
  test('parses all items directly from source without feed cap', () async {
    final xml = _buildRssXml(120);
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://example.com/feed.xml') {
        return http.Response(
          xml,
          200,
          headers: const <String, String>{
            'content-type': 'application/xml; charset=utf-8',
          },
        );
      }
      return http.Response('', 404);
    });

    final service = RssService(client: client);
    final result = await service.refreshFeed(
      const FeedSource(
        id: 'feed',
        title: 'Example',
        url: 'https://example.com/feed.xml',
        refreshInterval: Duration(minutes: 15),
      ),
      adBlockEnabled: true,
    );

    expect(result.items.length, 120);
    expect(result.items.first.title, 'Bài 120');
    expect(result.items.last.title, 'Bài 1');
  });

  test(
    'requests configured shelf gateway endpoint when gateway url is set',
    () async {
      final xml = _buildRssXml(12);
      final client = MockClient((request) async {
        if (request.url.host != 'localhost' || request.url.path != '/api/rss') {
          return http.Response('not found', 404);
        }
        final sourceUrl = request.url.queryParameters['url'];
        if (sourceUrl != 'https://example.com/feed.xml') {
          return http.Response('bad source url', 400);
        }
        return http.Response(
          xml,
          200,
          headers: const <String, String>{
            'content-type': 'application/xml; charset=utf-8',
          },
        );
      });

      final service = RssService(
        client: client,
        gatewayBaseUrl: 'http://localhost:8787',
      );
      final result = await service.refreshFeed(
        const FeedSource(
          id: 'feed',
          title: 'Example',
          url: 'https://example.com/feed.xml',
          refreshInterval: Duration(minutes: 15),
        ),
        adBlockEnabled: true,
      );

      expect(result.items.length, 12);
      expect(result.items.first.title, 'Bài 12');
    },
  );

  test('resolves relative article link against feed host', () async {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Example Feed</title>
    <item>
      <title>Bài A</title>
      <description><![CDATA[Mô tả A]]></description>
      <pubDate>2026-03-13T00:00:00Z</pubDate>
      <link>/articles/a?ref=rss</link>
      <guid>id-a</guid>
    </item>
  </channel>
</rss>
''';
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://news.example.com/feed.xml') {
        return http.Response(
          xml,
          200,
          headers: const <String, String>{
            'content-type': 'application/xml; charset=utf-8',
          },
        );
      }
      return http.Response('', 404);
    });

    final service = RssService(client: client);
    final result = await service.refreshFeed(
      const FeedSource(
        id: 'feed',
        title: 'News',
        url: 'https://news.example.com/feed.xml',
        refreshInterval: Duration(minutes: 15),
      ),
      adBlockEnabled: true,
    );

    expect(result.items, hasLength(1));
    expect(
      result.items.first.link,
      'https://news.example.com/articles/a?ref=rss',
    );
  });

  test('falls back to first anchor URL when item link is missing', () async {
    const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Example Feed</title>
    <item>
      <title>Bài B</title>
      <description><![CDATA[Xem <a href="https://example.com/articles/b">chi tiết</a>]]></description>
      <pubDate>2026-03-13T00:10:00Z</pubDate>
      <guid isPermaLink="false">item-b</guid>
    </item>
  </channel>
</rss>
''';
    final client = MockClient((request) async {
      if (request.url.toString() == 'https://example.com/feed.xml') {
        return http.Response(
          xml,
          200,
          headers: const <String, String>{
            'content-type': 'application/xml; charset=utf-8',
          },
        );
      }
      return http.Response('', 404);
    });

    final service = RssService(client: client);
    final result = await service.refreshFeed(
      const FeedSource(
        id: 'feed',
        title: 'Example',
        url: 'https://example.com/feed.xml',
        refreshInterval: Duration(minutes: 15),
      ),
      adBlockEnabled: true,
    );

    expect(result.items, hasLength(1));
    expect(result.items.first.link, 'https://example.com/articles/b');
  });
}

String _buildRssXml(int count) {
  final base = DateTime.utc(2026, 3, 13, 0, 0);
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<rss version="2.0">')
    ..writeln('<channel>')
    ..writeln('<title>Example Feed</title>');

  for (var index = 1; index <= count; index++) {
    final publishedAt = base.add(Duration(minutes: index)).toIso8601String();
    buffer
      ..writeln('<item>')
      ..writeln('<title>Bài $index</title>')
      ..writeln('<description><![CDATA[Mô tả $index]]></description>')
      ..writeln('<pubDate>$publishedAt</pubDate>')
      ..writeln('<link>https://example.com/articles/$index</link>')
      ..writeln('<guid>id-$index</guid>')
      ..writeln('</item>');
  }

  buffer
    ..writeln('</channel>')
    ..writeln('</rss>');
  return buffer.toString();
}
