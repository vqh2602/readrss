import 'package:flutter/material.dart';

class ArticleWebView extends StatelessWidget {
  const ArticleWebView({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.language, size: 28),
            const SizedBox(height: 12),
            Text(
              'Che do xem web truc tiep chi ho tro tren Flutter web.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SelectableText(url, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
