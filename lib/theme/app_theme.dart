import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens from DESIGN.md ("calm and sharp"). Every colour here is AA-checked
/// against the surface it is used on.
class AppColors extends ThemeExtension<AppColors> {
  final Color income;
  final Color expense;
  final Color muted; // secondary text
  final Color hairline; // 1px separators and card outlines
  final Color sunken; // inputs, chips, grouped-list background

  const AppColors({
    required this.income,
    required this.expense,
    required this.muted,
    required this.hairline,
    required this.sunken,
  });

  static const light = AppColors(
    income: Color(0xFF1D7444),
    expense: Color(0xFFBE3A2F),
    muted: Color(0xFF64605A),
    hairline: Color(0xFFE4E1DA),
    sunken: Color(0xFFEFEDE8),
  );

  static const dark = AppColors(
    income: Color(0xFF62CC8E),
    expense: Color(0xFFFF7B6E),
    muted: Color(0xFFA9A49A),
    hairline: Color(0xFF2E2C28),
    sunken: Color(0xFF242320),
  );

  @override
  AppColors copyWith({Color? income, Color? expense, Color? muted, Color? hairline, Color? sunken}) =>
      AppColors(
        income: income ?? this.income,
        expense: expense ?? this.expense,
        muted: muted ?? this.muted,
        hairline: hairline ?? this.hairline,
        sunken: sunken ?? this.sunken,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      sunken: Color.lerp(sunken, other.sunken, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

class AppTheme {
  // Radius scale (DESIGN.md): 16 sheets/blocks, 12 cards/groups, 10 controls.
  static const double rBlock = 16;
  static const double rCard = 12;
  static const double rControl = 10;

  static ThemeData get light => _build(
    Brightness.light,
    const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1F56C9),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFDDE6FA),
      onPrimaryContainer: Color(0xFF0F2A66),
      secondary: Color(0xFF1F56C9),
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFBE3A2F),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFBE4E1),
      onErrorContainer: Color(0xFF6E1A13),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF1C1B19),
      onSurfaceVariant: Color(0xFF64605A),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF6F5F2),
      surfaceContainer: Color(0xFFEFEDE8),
      surfaceContainerHigh: Color(0xFFE9E7E1),
      surfaceContainerHighest: Color(0xFFE3E0D9),
      outline: Color(0xFF8C877E),
      outlineVariant: Color(0xFFE4E1DA),
      inverseSurface: Color(0xFF2A2926),
      onInverseSurface: Color(0xFFF2F0EB),
      inversePrimary: Color(0xFF8EB0FF),
    ),
    background: const Color(0xFFF6F5F2),
    colors: AppColors.light,
  );

  static ThemeData get dark => _build(
    Brightness.dark,
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF8EB0FF),
      onPrimary: Color(0xFF0F1E40),
      primaryContainer: Color(0xFF233A6E),
      onPrimaryContainer: Color(0xFFDDE6FA),
      secondary: Color(0xFF8EB0FF),
      onSecondary: Color(0xFF0F1E40),
      error: Color(0xFFFF7B6E),
      onError: Color(0xFF3B0A05),
      errorContainer: Color(0xFF5A1E18),
      onErrorContainer: Color(0xFFFFDAD5),
      surface: Color(0xFF1B1A18),
      onSurface: Color(0xFFF2F0EB),
      onSurfaceVariant: Color(0xFFA9A49A),
      surfaceContainerLowest: Color(0xFF131211),
      surfaceContainerLow: Color(0xFF181715),
      surfaceContainer: Color(0xFF242320),
      surfaceContainerHigh: Color(0xFF2A2926),
      surfaceContainerHighest: Color(0xFF32302C),
      outline: Color(0xFF79746A),
      outlineVariant: Color(0xFF2E2C28),
      inverseSurface: Color(0xFFF2F0EB),
      onInverseSurface: Color(0xFF1C1B19),
      inversePrimary: Color(0xFF1F56C9),
    ),
    background: const Color(0xFF131211),
    colors: AppColors.dark,
  );

  static ThemeData _build(
    Brightness brightness,
    ColorScheme scheme, {
    required Color background,
    required AppColors colors,
  }) {
    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true);
    // Plus Jakarta Sans: designed for Jakarta's identity (DESIGN.md "Typeface").
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.plusJakartaSans(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.4),
      headlineSmall: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleLarge: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w600),
      labelSmall: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w600),
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final hairline = BorderSide(color: colors.hairline);
    RoundedRectangleBorder rounded(double r, [BorderSide side = BorderSide.none]) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: side);
    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(rControl),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      extensions: [colors],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      // Flat surfaces separated by tone + hairline; shadow is reserved for floating things.
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded(rCard, hairline),
      ),
      dividerTheme: DividerThemeData(color: colors.hairline, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(color: colors.muted),
        minVerticalPadding: 10,
        shape: rounded(rCard),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.sunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        hintStyle: text.bodyLarge?.copyWith(color: colors.muted),
        labelStyle: text.bodyMedium?.copyWith(color: colors.muted),
        prefixIconColor: colors.muted,
        suffixIconColor: colors.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded(rControl),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: rounded(rControl),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 44), shape: rounded(rControl), textStyle: text.labelLarge),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: hairline,
        shape: rounded(rControl),
        labelStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        highlightElevation: 4,
        shape: rounded(rBlock),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: rounded(rControl),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected) ? scheme.onSurface : colors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? scheme.primary : colors.muted,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: colors.hairline,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(rBlock))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded(rBlock),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        shape: rounded(rControl),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: rounded(rControl),
          side: hairline,
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          foregroundColor: scheme.onSurface,
          textStyle: text.labelLarge,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}

/// Amounts everywhere use tabular figures so rupiah columns line up (DESIGN.md motif).
const tabularFigures = [FontFeature.tabularFigures()];
