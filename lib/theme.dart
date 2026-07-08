import 'package:flutter/material.dart';

/// Bespoke theme translated from the agreed prototype (direction D + mono palette):
/// flat, tight, monochrome — Linear/Attio. Near-black ink is the only accent; no
/// tonal M3 fills (surfaceTint transparent), small radii, hairline dividers, compact
/// density. Both light and dark are first-class. (Decision 8's "theming slice".)
class AppTheme {
  AppTheme._();

  // ---- radii / density -----------------------------------------------------
  static const _radius = 10.0;
  static const _fieldRadius = 8.0;

  // ---- light tokens (from the prototype) -----------------------------------
  static const _inkL = Color(0xFF191C1E);
  static const _inkSoftL = Color(0xFF43474C);
  static const _baseL = Color(0xFFFDFDFF);
  static const _outlineL = Color(0xFFC3C6CD);
  static const _dividerL = Color(0xFFE5E7EC);
  static const _neutralChipL = Color(0xFFECEEF2);

  // ---- dark tokens ---------------------------------------------------------
  static const _inkD = Color(0xFFE3E2E6);
  static const _inkSoftD = Color(0xFFA9ADB6);
  static const _baseD = Color(0xFF121316);
  static const _outlineD = Color(0xFF3B3E45);
  static const _dividerD = Color(0xFF26282D);
  static const _neutralChipD = Color(0xFF26282D);

  static ThemeData get light => _build(
    brightness: Brightness.light,
    ink: _inkL,
    inkSoft: _inkSoftL,
    base: _baseL,
    outline: _outlineL,
    divider: _dividerL,
    chip: _neutralChipL,
    surfaceContainers: const [
      Colors.white,
      Color(0xFFF7F8FA),
      Color(0xFFF3F4F7),
      Color(0xFFEEEFF3),
      Color(0xFFE9EAEF),
    ],
    error: const Color(0xFFBA1A1A),
    onError: Colors.white,
    errorContainer: const Color(0xFFFFDAD6),
    onErrorContainer: const Color(0xFF410002),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    ink: _inkD,
    inkSoft: _inkSoftD,
    base: _baseD,
    outline: _outlineD,
    divider: _dividerD,
    chip: _neutralChipD,
    surfaceContainers: const [
      Color(0xFF0E0F12),
      Color(0xFF161718),
      Color(0xFF1A1B1F),
      Color(0xFF212327),
      Color(0xFF2A2C31),
    ],
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
    errorContainer: const Color(0xFF93000A),
    onErrorContainer: const Color(0xFFFFDAD6),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color ink,
    required Color inkSoft,
    required Color base,
    required Color outline,
    required Color divider,
    required Color chip,
    required List<Color> surfaceContainers,
    required Color error,
    required Color onError,
    required Color errorContainer,
    required Color onErrorContainer,
  }) {
    // Mono: the accent IS the ink. Buttons are ink-filled with base-colored text.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: base,
      primaryContainer: chip,
      onPrimaryContainer: ink,
      secondary: inkSoft,
      onSecondary: base,
      secondaryContainer: chip,
      onSecondaryContainer: inkSoft,
      tertiary: inkSoft,
      onTertiary: base,
      tertiaryContainer: chip,
      onTertiaryContainer: inkSoft,
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: base,
      onSurface: ink,
      onSurfaceVariant: inkSoft,
      outline: outline,
      outlineVariant: divider,
      surfaceContainerLowest: surfaceContainers[0],
      surfaceContainerLow: surfaceContainers[1],
      surfaceContainer: surfaceContainers[2],
      surfaceContainerHigh: surfaceContainers[3],
      surfaceContainerHighest: surfaceContainers[4],
      inverseSurface: ink,
      onInverseSurface: base,
      inversePrimary: inkSoft,
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent, // kill M3 tonal elevation → truly flat
    );

    final baseText =
        (brightness == Brightness.light
                ? Typography.blackMountainView
                : Typography.whiteMountainView)
            .apply(bodyColor: ink, displayColor: ink);

    // ONE explicit type scale (single source of truth). Roboto, exactly three
    // weights so hierarchy comes from size + weight, never accident:
    //   w600 — screen titles, entity names, buttons
    //   w500 — field labels (detail + form, same style)
    //   w400 — body values, input text, secondary/meta
    final textTheme = baseText.copyWith(
      // detail screen name
      headlineSmall: baseText.headlineSmall?.copyWith(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: ink,
      ),
      // app bar / screen titles
      titleLarge: baseText.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: ink,
      ),
      // section / empty-state headings
      titleMedium: baseText.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: ink,
      ),
      // body values + text-field input (same style → identical across screens)
      bodyLarge: baseText.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: ink,
      ),
      // secondary / subtitle / meta
      bodyMedium: baseText.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: inkSoft,
      ),
      // buttons
      labelLarge: baseText.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: ink,
      ),
      // field labels (detail rows + form floating labels use THIS, identically)
      labelMedium: baseText.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: inkSoft,
      ),
    );

    OutlineInputBorder fieldBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
          borderSide: BorderSide(color: c, width: w),
        );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_radius),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      visualDensity: VisualDensity.compact,
      textTheme: textTheme,
      dividerColor: divider,
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: divider)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_fieldRadius),
          ),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_fieldRadius),
          ),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 1,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
        extendedTextStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: fieldBorder(scheme.outline),
        enabledBorder: fieldBorder(scheme.outline),
        focusedBorder: fieldBorder(scheme.primary, 1.5),
        errorBorder: fieldBorder(scheme.error),
        focusedErrorBorder: fieldBorder(scheme.error, 1.5),
        // resting label = body size (sits on the input line); floated label uses the
        // SAME field-label style as the detail screen's row labels.
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.labelMedium,
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_fieldRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
    );
  }
}
