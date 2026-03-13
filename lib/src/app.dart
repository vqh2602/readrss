import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'controller/rss_controller.dart';
import 'models.dart';
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
          theme: _buildTheme(
            Brightness.light,
            _controller.settings.themePreset,
          ),
          darkTheme: _buildTheme(
            Brightness.dark,
            _controller.settings.themePreset,
          ),
          home: ReadRssHomePage(controller: _controller),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness, AppThemePreset preset) {
    final isDark = brightness == Brightness.dark;
    final palette = _paletteFor(preset, isDark);
    final base = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: palette.seed,
    );
    final colorScheme = base.copyWith(
      primary: palette.primary,
      secondary: palette.secondary,
      tertiary: palette.tertiary,
      surface: palette.surface,
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

  _AppThemePalette _paletteFor(AppThemePreset preset, bool isDark) {
    return switch (preset) {
      AppThemePreset.ocean =>
        isDark
            ? const _AppThemePalette(
                seed: Color(0xFF74F2CE),
                primary: Color(0xFF74F2CE),
                secondary: Color(0xFFFFB38A),
                tertiary: Color(0xFF8ACBFF),
                surface: Color(0xFF152128),
              )
            : const _AppThemePalette(
                seed: Color(0xFF116A7B),
                primary: Color(0xFF116A7B),
                secondary: Color(0xFFFF7A59),
                tertiary: Color(0xFF5DADEC),
                surface: Color(0xFFF7F4EC),
              ),
      AppThemePreset.sunset =>
        isDark
            ? const _AppThemePalette(
                seed: Color(0xFFFF9F80),
                primary: Color(0xFFFF9F80),
                secondary: Color(0xFFFFC78A),
                tertiary: Color(0xFFCFA8FF),
                surface: Color(0xFF2A1B1A),
              )
            : const _AppThemePalette(
                seed: Color(0xFFB85042),
                primary: Color(0xFFB85042),
                secondary: Color(0xFFF2A65A),
                tertiary: Color(0xFF6D597A),
                surface: Color(0xFFFDF4EE),
              ),
      AppThemePreset.forest =>
        isDark
            ? const _AppThemePalette(
                seed: Color(0xFF8FD694),
                primary: Color(0xFF8FD694),
                secondary: Color(0xFF7FD1B9),
                tertiary: Color(0xFFC6E48B),
                surface: Color(0xFF14201A),
              )
            : const _AppThemePalette(
                seed: Color(0xFF2E7D32),
                primary: Color(0xFF2E7D32),
                secondary: Color(0xFF6C9A8B),
                tertiary: Color(0xFFA3B18A),
                surface: Color(0xFFF1F8F2),
              ),
      AppThemePreset.sakura =>
        isDark
            ? const _AppThemePalette(
                seed: Color(0xFFFF8AB3),
                primary: Color(0xFFFF8AB3),
                secondary: Color(0xFFFFB3A7),
                tertiary: Color(0xFFB8A5FF),
                surface: Color(0xFF241620),
              )
            : const _AppThemePalette(
                seed: Color(0xFFC2185B),
                primary: Color(0xFFC2185B),
                secondary: Color(0xFFFF8A80),
                tertiary: Color(0xFF7B6CF6),
                surface: Color(0xFFFFF1F6),
              ),
      AppThemePreset.sand =>
        isDark
            ? const _AppThemePalette(
                seed: Color(0xFFD7B59A),
                primary: Color(0xFFD7B59A),
                secondary: Color(0xFFFFCF77),
                tertiary: Color(0xFF9BA8FF),
                surface: Color(0xFF221B16),
              )
            : const _AppThemePalette(
                seed: Color(0xFF8D6E63),
                primary: Color(0xFF8D6E63),
                secondary: Color(0xFFE9A03B),
                tertiary: Color(0xFF5C6BC0),
                surface: Color(0xFFF8F2E6),
              ),
      AppThemePreset.slate =>
        isDark
            ? const _AppThemePalette(
                seed: Color(0xFFB0BEC5),
                primary: Color(0xFFB0BEC5),
                secondary: Color(0xFF90A4AE),
                tertiary: Color(0xFF78909C),
                surface: Color(0xFF171C21),
              )
            : const _AppThemePalette(
                seed: Color(0xFF455A64),
                primary: Color(0xFF455A64),
                secondary: Color(0xFF607D8B),
                tertiary: Color(0xFF90A4AE),
                surface: Color(0xFFF2F4F6),
              ),
    };
  }
}

class _AppThemePalette {
  const _AppThemePalette({
    required this.seed,
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.surface,
  });

  final Color seed;
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color surface;
}
