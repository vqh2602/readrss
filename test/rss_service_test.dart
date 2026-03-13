import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:readrss/src/models.dart';
import 'package:readrss/src/services/rss_service.dart';

void main() {
  test(
    'parses all items from allorigins get payload without feed cap',
    () async {
      final xml = _buildRssXml(120);
      final client = MockClient((request) async {
        if (request.url.toString() == 'https://example.com/feed.xml') {
          return http.Response('blocked by cors', 403);
        }
        if (request.url.host == 'api.allorigins.win' &&
            request.url.path.endsWith('/get')) {
          return http.Response(
            jsonEncode(<String, dynamic>{'contents': xml}),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }
        return http.Response('', 500);
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
    },
  );
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
