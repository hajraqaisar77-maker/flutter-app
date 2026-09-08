import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Builds the app's light and dark [ThemeData]. Typography pairs a serif
/// display face (Amiri — used for prayer names and Arabic text) with a
/// clean sans body face (Poppins) for a premium, editorial feel.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        bg: AppColors.darkBg,
        surface: AppColors.darkSurface,
        surfaceAlt: AppColors.darkSurfaceAlt,
        textPrimary: AppColors.darkTextPrimary,
        textMuted: AppColors.darkTextMuted,
        line: AppColors.darkLine,
      );

  static ThemeData get light => _build(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        surfaceAlt: AppColors.lightSurfaceAlt,
        textPrimary: AppColors.lightTextPrimary,
        textMuted: AppColors.lightTextMuted,
        line: AppColors.lightLine,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surfaceAlt,
    required Color textPrimary,
    required Color textMuted,
    required Color line,
  }) {
    final base = ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AppColors.gold,
        onPrimary: brightness == Brightness.dark ? AppColors.darkBg : Colors.white,
        secondary: AppColors.goldSoft,
        onSecondary: AppColors.darkBg,
        error: AppColors.danger,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      fontFamily: GoogleFonts.poppins().fontFamily,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.amiri(fontSize: 34, color: AppColors.goldSoft, fontWeight: FontWeight.w700),
        displayMedium: GoogleFonts.amiri(fontSize: 26, color: AppColors.goldSoft, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.amiri(fontSize: 20, color: textPrimary, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: textPrimary),
        bodySmall: GoogleFonts.poppins(fontSize: 12, color: textMuted),
        labelSmall: GoogleFonts.poppins(fontSize: 11, color: textMuted, letterSpacing: 1.2),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.amiri(fontSize: 22, color: AppColors.goldSoft, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: line, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.gold.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(GoogleFonts.poppins(fontSize: 11)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.gold : textMuted,
        ),
      ),
    );

    return base.copyWith(
      extensions: [
        AppSurfaceColors(surfaceAlt: surfaceAlt, line: line, textMuted: textMuted),
      ],
    );
  }
}

/// Extra surface tokens not covered by [ColorScheme], kept as a theme
/// extension so widgets can read them via `Theme.of(context).extension`.
class AppSurfaceColors extends ThemeExtension<AppSurfaceColors> {
  final Color surfaceAlt;
  final Color line;
  final Color textMuted;

  const AppSurfaceColors({required this.surfaceAlt, required this.line, required this.textMuted});

  @override
  AppSurfaceColors copyWith({Color? surfaceAlt, Color? line, Color? textMuted}) => AppSurfaceColors(
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        line: line ?? this.line,
        textMuted: textMuted ?? this.textMuted,
      );

  @override
  AppSurfaceColors lerp(ThemeExtension<AppSurfaceColors>? other, double t) {
    if (other is! AppSurfaceColors) return this;
    return AppSurfaceColors(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      line: Color.lerp(line, other.line, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}
