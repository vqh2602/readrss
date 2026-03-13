import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'controller/rss_controller.dart';
import 'ui/home_page.dart';

class ReadRssApp extends StatefulWidget {
  const ReadRssApp({super.key, this.controller});

  final RssController? controller;

  @override
  State<ReadRssApp> createState() => _ReadRssAppState();
}

class _ReadRssAppState extends State<ReadRssApp> {
  late final RssController _controller = widget.controller ?? RssController();

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return MaterialApp(
          title: 'RSS News Hub',
          debugShowCheckedModeBanner: false,
          themeMode: _controller.settings.themeMode,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          home: ReadRssHomePage(controller: _controller),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: isDark ? const Color(0xFF74F2CE) : const Color(0xFF116A7B),
    );
    final colorScheme = base.copyWith(
      primary: isDark ? const Color(0xFF74F2CE) : const Color(0xFF116A7B),
      secondary: isDark ? const Color(0xFFFFB38A) : const Color(0xFFFF7A59),
      surface: isDark ? const Color(0xFF152128) : const Color(0xFFF7F4EC),
    );
    final textTheme = GoogleFonts.soraTextTheme().copyWith(
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.spaceGrotesk(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.spaceGrotesk(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      headlineSmall: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.spaceGrotesk(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.sora(fontSize: 12.5, fontWeight: FontWeight.w500),
      bodyMedium: GoogleFonts.sora(fontSize: 11.5, fontWeight: FontWeight.w500),
      bodySmall: GoogleFonts.sora(fontSize: 10, fontWeight: FontWeight.w500),
      labelLarge: GoogleFonts.sora(fontSize: 11, fontWeight: FontWeight.w700),
      labelSmall: GoogleFonts.sora(fontSize: 9.5, fontWeight: FontWeight.w700),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: colorScheme.surface.withValues(alpha: isDark ? 0.82 : 0.92),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.surface,
        ),
      ),
      dividerColor: colorScheme.onSurface.withValues(alpha: 0.08),
    );
  }
}
