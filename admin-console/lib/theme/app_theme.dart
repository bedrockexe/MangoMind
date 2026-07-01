import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized design system for the MangoMind admin console.
///
/// Shared with the farmer app so both surfaces look like one product. Everything
/// visual flows from here: the color palette (mango-green + amber/orange,
/// matching the brand banner), typography, spacing scale, and the shared
/// component themes (cards, buttons, inputs, chips…). Screens should read colors
/// from `Theme.of(context).colorScheme.*` rather than hardcoding `Colors.*`, so
/// light/dark mode and any future rebrand "just work".
class AppTheme {
  AppTheme._();

  // --- Brand seed colors (from docs/banner.svg) ---------------------------
  /// Primary brand green.
  static const Color brandGreen = Color(0xFF166534);

  /// Deep canopy green (used for dark surfaces / gradients).
  static const Color brandGreenDeep = Color(0xFF052E16);

  /// Warm mango amber — the secondary accent.
  static const Color brandAmber = Color(0xFFF59E0B);

  /// Ripe mango orange — used sparingly for highlights/CTAs.
  static const Color brandOrange = Color(0xFFF97316);

  // --- Spacing scale (8pt grid) -------------------------------------------
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 24;
  static const double space6 = 32;

  // --- Corner radii --------------------------------------------------------
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(radiusMd));

  // --- Public theme getters ------------------------------------------------
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  // --- Theme builder -------------------------------------------------------
  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: brandGreen,
      brightness: brightness,
      // Pin the brand accents so they survive M3 tonal mapping.
      primary: isDark ? const Color(0xFF4ADE80) : brandGreen,
      secondary: brandAmber,
      tertiary: brandOrange,
    );

    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B1410) : const Color(0xFFF6F8F4),
      textTheme: textTheme,

      // AppBar — flat, surface-colored, brand-tinted title.
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),

      // Cards — soft rounded, low elevation, subtle outline.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(
          horizontal: space4,
          vertical: space2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
      ),

      // Inputs — filled, rounded, no harsh borders until focused.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.4)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space4,
          vertical: space3 + 2,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
      ),

      // Filled buttons — the primary CTA style.
      // NOTE: use Size(64, 52) (min height only) rather than
      // Size.fromHeight(52), which is Size(infinity, 52) and forces infinite
      // width on any button placed inside a Row/unbounded-width parent.
      // Screens that want full-width buttons already wrap them (SizedBox /
      // stretch), so they still expand correctly.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),

      // Elevated buttons — kept consistent with filled for legacy call sites.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, 52),
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          side: BorderSide(color: scheme.outline),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Chips — used for the feature pills / filters.
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),

      // FAB — brand green, fully rounded.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      // Bottom nav — surface, brand-tinted selection.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 1,
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 1,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: space5,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),

      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
    );
  }
}
