import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _articleWebViewCounter = 0;
final String _articleWebViewPrefix = DateTime.now().microsecondsSinceEpoch
    .toString();

class ArticleWebView extends StatefulWidget {
  const ArticleWebView({super.key, required this.url});

  final String url;

  @override
  State<ArticleWebView> createState() => _ArticleWebViewState();
}

class _ArticleWebViewState extends State<ArticleWebView> {
  late String _viewType = _registerView(widget.url);

  @override
  void didUpdateWidget(covariant ArticleWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _viewType = _registerView(widget.url);
      });
    }
  }

  String _registerView(String url) {
    final viewType =
        'article-web-view-$_articleWebViewPrefix-${_articleWebViewCounter++}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.backgroundColor = 'transparent'
        ..style.borderRadius = '24px';
      iframe.setAttribute(
        'allow',
        'fullscreen; clipboard-read; clipboard-write',
      );
      iframe.setAttribute('loading', 'eager');
      iframe.setAttribute('referrerpolicy', 'strict-origin-when-cross-origin');
      return iframe;
    });
    return viewType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
