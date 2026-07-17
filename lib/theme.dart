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
      // Chips: the mono treatment Decision 13 promises but never delivered — without this,
      // InputChip ships stock M3 (outlined, 8px radius, `labelLarge` = our BUTTON style)
      // beside the tight pill on the task rows, so one category rendered two ways
      // (Decision 47).
      chipTheme: ChipThemeData(
        // A true pill — matches `_CategoryChip`'s circular(999) on the task rows.
        shape: const StadiumBorder(),
        backgroundColor: scheme.secondaryContainer,
        // LOAD-BEARING, not belt-and-braces: StadiumBorder's own default side IS
        // BorderSide.none, so without this `Chip._getShape` falls through to
        // `resolvedShape.copyWith(side: chipDefaults.side)` and the outlineVariant
        // hairline comes back. Deleting this "redundant" line un-does the flat look.
        side: BorderSide.none,
        // The M3 default is `labelLarge` — which THIS theme defines as the button style
        // (w600/14). labelMedium (w500/12.5) sits beside the row pill's labelSmall.
        // copyWith(onSurface) because labelMedium carries `inkSoft`, and Chip merges the
        // theme style — so the bare role would mute contact names, while the row pill
        // (`_CategoryChip`) paints its name at full onSurface. Same token, both places.
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        // Compact the HORIZONTAL axis only; KEEP M3's vertical 8. Shrinking the vertical
        // does NOT shrink the chip: `contentSize = max(_kChipHeight - padding.vertical, …)`,
        // so height stays pinned at the 32px floor while the avatar and ✕ — which are laid
        // out in a tightFor(contentSize) box — inflate to fill it. `symmetric(horizontal: 4)`
        // alone would zero the vertical and blow contentSize 20 → 32.
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      // Every new M3 component we introduce gets mono treatment so nothing ships
      // with a default tonal fill against the flat theme (Decision 13).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor:
            scheme.primaryContainer, // neutral chip, not a tonal pill
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelMedium!.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        selectedIconTheme: IconThemeData(size: 22, color: scheme.onSurface),
        unselectedIconTheme: IconThemeData(
          size: 22,
          color: scheme.onSurfaceVariant,
        ),
        selectedLabelTextStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: textTheme.labelMedium!.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary, // ink underline
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: scheme.onSurface,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        dividerColor: divider,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
      // All-day toggle: mono + flat — ink track when on, base thumb, hairline outline.
      // (Default M3 Switch is a tonal pill; treat it like every other component here.)
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest,
        ),
        trackOutlineColor: WidgetStateProperty.all(scheme.outline),
        trackOutlineWidth: WidgetStateProperty.all(1),
      ),
      // showTimePicker is new surface: its dial/fields default to tonal fills. Keep it
      // mono — ink hand, neutral-chip selection, flat surface.
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
        hourMinuteTextColor: scheme.onSurface,
        dialBackgroundColor: scheme.surfaceContainerHighest,
        dialHandColor: scheme.primary,
        dialTextColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
        dayPeriodColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : Colors.transparent,
        ),
        dayPeriodTextColor: scheme.onSurface,
        dayPeriodBorderSide: BorderSide(color: scheme.outline),
        entryModeIconColor: scheme.onSurfaceVariant,
        shape: shape,
      ),
      // The one "raised object" the flat theme has: a calendar event block. Centralized
      // so the timeline doesn't scatter guessed surfaceContainer levels — border-defined
      // (not fill-alone) so it reads in light AND dark.
      extensions: [
        EventBlockStyle(
          fill: scheme.surfaceContainerHigh,
          border: scheme.outlineVariant,
        ),
      ],
    );
  }
}

/// Visual tokens for a calendar event block (timeline). A hairline [border] + [fill] makes
/// it read as a solid object on the flat canvas (fill-delta alone fails the squint test in
/// light). This is the mono **no-type** default; a typed event replaces [fill] with a hue
/// tint (see `tintForType`) while keeping the same border — so the border carries
/// objecthood and colour is pure enrichment. (Decision 19 retired the left rail — a
/// coloured edge was the AI-slop tell.)
@immutable
class EventBlockStyle extends ThemeExtension<EventBlockStyle> {
  const EventBlockStyle({required this.fill, required this.border});

  final Color fill;
  final Color border;

  @override
  EventBlockStyle copyWith({Color? fill, Color? border}) =>
      EventBlockStyle(fill: fill ?? this.fill, border: border ?? this.border);

  @override
  EventBlockStyle lerp(EventBlockStyle? other, double t) {
    if (other == null) return this;
    return EventBlockStyle(
      fill: Color.lerp(fill, other.fill, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
