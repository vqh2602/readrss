import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> main(List<String> args) async {
  final host =
      _readArg(args, '--host') ??
      Platform.environment['RSS_GATEWAY_HOST'] ??
      '0.0.0.0';
  final port =
      int.tryParse(
        _readArg(args, '--port') ??
            Platform.environment['RSS_GATEWAY_PORT'] ??
            Platform.environment['PORT'] ??
            '8787',
      ) ??
      8787;

  final client = http.Client();
  final router = Router()
    ..get('/health', (Request request) {
      return Response.ok(
        jsonEncode(<String, dynamic>{'ok': true, 'service': 'rss-gateway'}),
        headers: const <String, String>{
          'content-type': 'application/json; charset=utf-8',
        },
      );
    })
    ..get('/api/rss', (Request request) async {
      final rawUrl = request.url.queryParameters['url']?.trim();
      if (rawUrl == null || rawUrl.isEmpty) {
        return Response(
          400,
          body: 'Thiếu query parameter url.',
          headers: const <String, String>{
            'content-type': 'text/plain; charset=utf-8',
          },
        );
      }

      final target = _parseTargetUri(rawUrl);
      if (target == null) {
        return Response(
          400,
          body: 'URL RSS không hợp lệ hoặc không được phép.',
          headers: const <String, String>{
            'content-type': 'text/plain; charset=utf-8',
          },
        );
      }

      try {
        final upstreamResponse = await client.get(
          target,
          headers: const <String, String>{
            'accept':
                'application/rss+xml, application/atom+xml, application/xml, text/xml, application/feed+json, application/json;q=0.9, */*;q=0.8',
            'user-agent': 'RSSNewsHub-Gateway/1.0',
          },
        );
        final passthroughHeaders = <String, String>{};
        for (final entry in upstreamResponse.headers.entries) {
          if (!_hopByHopHeaders.contains(entry.key.toLowerCase())) {
            passthroughHeaders[entry.key] = entry.value;
          }
        }
        return Response(
          upstreamResponse.statusCode,
          body: upstreamResponse.bodyBytes,
          headers: <String, String>{
            ...passthroughHeaders,
            if (!passthroughHeaders.containsKey('content-type'))
              'content-type': 'application/xml; charset=utf-8',
            'cache-control': 'no-store',
          },
        );
      } catch (error) {
        return Response(
          502,
          body: 'Gateway error: $error',
          headers: const <String, String>{
            'content-type': 'text/plain; charset=utf-8',
          },
        );
      }
    });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        corsHeaders(
          headers: <String, String>{
            ACCESS_CONTROL_ALLOW_ORIGIN: '*',
            ACCESS_CONTROL_ALLOW_METHODS: 'GET, OPTIONS',
            ACCESS_CONTROL_ALLOW_HEADERS: 'Origin, Content-Type, Accept',
          },
        ),
      )
      .addHandler(router.call);

  final server = await shelf_io.serve(handler, host, port);
  stdout.writeln(
    'RSS Gateway running at http://${server.address.host}:${server.port}',
  );
}

String? _readArg(List<String> args, String flag) {
  final byValueIndex = args.indexOf(flag);
  if (byValueIndex != -1 && byValueIndex + 1 < args.length) {
    return args[byValueIndex + 1];
  }
  final byEqualPrefix = '$flag=';
  for (final value in args) {
    if (value.startsWith(byEqualPrefix)) {
      return value.substring(byEqualPrefix.length);
    }
  }
  return null;
}

Uri? _parseTargetUri(String rawUrl) {
  final parsed = Uri.tryParse(rawUrl);
  if (parsed == null ||
      !parsed.hasAuthority ||
      (parsed.scheme != 'http' && parsed.scheme != 'https')) {
    return null;
  }
  if (_isBlockedHost(parsed.host)) {
    return null;
  }
  return parsed;
}

bool _isBlockedHost(String host) {
  final normalized = host.toLowerCase();
  if (normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1') {
    return true;
  }
  final ip = InternetAddress.tryParse(host);
  if (ip == null) {
    return false;
  }
  if (ip.type == InternetAddressType.IPv4) {
    final bytes = ip.rawAddress;
    final first = bytes[0];
    final second = bytes[1];
    if (first == 10) {
      return true;
    }
    if (first == 172 && second >= 16 && second <= 31) {
      return true;
    }
    if (first == 192 && second == 168) {
      return true;
    }
    if (first == 127) {
      return true;
    }
  } else if (ip.type == InternetAddressType.IPv6) {
    if (ip.isLoopback || ip.isLinkLocal || ip.isMulticast) {
      return true;
    }
    final bytes = ip.rawAddress;
    if (bytes[0] & 0xFE == 0xFC) {
      return true;
    }
  }
  return false;
}

const Set<String> _hopByHopHeaders = <String>{
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'content-length',
};
