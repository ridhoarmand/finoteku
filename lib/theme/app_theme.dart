import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // iOS-inspired color scheme dengan warna yang lebih soft dan natural
  static const FlexSchemeColor _iOSScheme = FlexSchemeColor(
    primary: Color(0xFF007AFF), // iOS Blue
    primaryContainer: Color(0xFFE3F2FD),
    secondary: Color(0xFF34C759), // iOS Green
    secondaryContainer: Color(0xFFE8F5E8),
    tertiary: Color(0xFFAF52DE), // iOS Purple
    tertiaryContainer: Color(0xFFF3E5F5),
    appBarColor: Color(0xFFF2F2F7), // iOS Gray 6
    error: Color(0xFFFF3B30), // iOS Red
  );

  static ThemeData get light => FlexThemeData.light(
    colors: _iOSScheme,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 1, // Minimal blending untuk tampilan yang lebih bersih seperti iOS
    subThemesData: FlexSubThemesData(
      // Button themes - iOS style dengan rounded corners yang lebih besar
      elevatedButtonSchemeColor: SchemeColor.primary,
      elevatedButtonRadius: 14.0, // iOS button radius
      filledButtonRadius: 14.0,
      outlinedButtonRadius: 14.0,
      textButtonRadius: 14.0,
      elevatedButtonElevation: 0, // iOS buttons tidak memiliki shadow
      
      // Input decoration - iOS style yang lebih compact dan elegant
      inputDecoratorRadius: 12.0, // iOS input field radius
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorIsFilled: true,
      inputDecoratorFillColor: Color(0xFFFAFAFA), // Lebih terang dari gray 6
      inputDecoratorBorderWidth: 0.8,
      inputDecoratorFocusedBorderWidth: 1.5,
      inputDecoratorUnfocusedBorderIsColored: false,
      inputDecoratorBorderSchemeColor: SchemeColor.outline,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.onSurfaceVariant,
      
      // Card theme - iOS style dengan corner radius yang lebih besar
      cardRadius: 16.0, // iOS card radius
      cardElevation: 0, // iOS menggunakan borders, bukan shadows
      
      // AppBar theme - iOS navigation bar style
      appBarScrolledUnderElevation: 0,
      appBarBackgroundSchemeColor: SchemeColor.surface,
      appBarForegroundSchemeColor: SchemeColor.onSurface,
      
      // Navigation theme
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.primary,
      navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
      navigationBarElevation: 0,
      
      // Other settings
      blendOnLevel: 2,
      blendOnColors: false,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: false, // iOS style dividers
      defaultRadius: 14.0, // iOS default radius
      
      // Switch theme - iOS style
      switchThumbSchemeColor: SchemeColor.surface,
      
      // Chip theme - iOS style
      chipRadius: 20.0,
      chipSchemeColor: SchemeColor.primaryContainer,
      
      // Dialog theme - iOS style
      dialogRadius: 20.0,
      dialogElevation: 0,
    ),
    // San Francisco font (iOS default) fallback ke Inter
    fontFamily: GoogleFonts.inter().fontFamily,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  ).copyWith(
    // Custom enhancements untuk iOS style
    dividerTheme: const DividerThemeData(
      thickness: 0.5, // iOS thin dividers
      space: 0.5,
      color: Color(0xFFC6C6C8), // iOS System Gray 4
    ),
    scaffoldBackgroundColor: const Color(0xFFF2F2F7), // iOS System Gray 6
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: const Color(0xFFE5E5EA), // iOS System Gray 5
          width: 0.5,
        ),
      ),
      color: Colors.white,
    ),
    // iOS style bottom sheet
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFFF2F2F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
    ),
    // Custom input decoration theme untuk tampilan yang lebih compact
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Lebih compact
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: const Color(0xFFE5E5EA), // iOS System Gray 5
          width: 0.8,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: const Color(0xFFE5E5EA), // iOS System Gray 5
          width: 0.8,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Color(0xFF007AFF), // iOS Blue
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Color(0xFFFF3B30), // iOS Red
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Color(0xFFFF3B30), // iOS Red
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFA), // Warna background yang lebih soft
      hintStyle: TextStyle(
        color: const Color(0xFF8E8E93), // iOS System Gray
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        color: const Color(0xFF8E8E93), // iOS System Gray
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(
        color: const Color(0xFF007AFF), // iOS Blue
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
      ),
    ),
  );

  static ThemeData get dark => FlexThemeData.dark(
    colors: const FlexSchemeColor(
      primary: Color(0xFF0A84FF), // iOS Blue (dark mode)
      primaryContainer: Color(0xFF1E3A8A),
      secondary: Color(0xFF32D74B), // iOS Green (dark mode)
      secondaryContainer: Color(0xFF065F46),
      tertiary: Color(0xBF5AC8FA), // iOS Purple (dark mode)
      tertiaryContainer: Color(0xFF6B21A8),
      appBarColor: Color(0xFF1C1C1E), // iOS System Gray (dark mode)
      error: Color(0xFFFF453A), // iOS Red (dark mode)
    ),
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 2,
    subThemesData: FlexSubThemesData(
      // Button themes
      elevatedButtonSchemeColor: SchemeColor.primary,
      elevatedButtonRadius: 14.0,
      filledButtonRadius: 14.0,
      outlinedButtonRadius: 14.0,
      textButtonRadius: 14.0,
      elevatedButtonElevation: 0,
      
      // Input decoration - dark mode iOS style
      inputDecoratorRadius: 12.0,
      inputDecoratorBorderType: FlexInputBorderType.outline,
      inputDecoratorIsFilled: true,
      inputDecoratorFillColor: Color(0xFF2C2C2E), // iOS System Gray yang lebih terang
      inputDecoratorBorderWidth: 0.8,
      inputDecoratorFocusedBorderWidth: 1.5,
      inputDecoratorUnfocusedBorderIsColored: false,
      inputDecoratorBorderSchemeColor: SchemeColor.outline,
      inputDecoratorPrefixIconSchemeColor: SchemeColor.onSurfaceVariant,
      
      // Card theme
      cardRadius: 16.0,
      cardElevation: 0,
      
      // AppBar theme
      appBarScrolledUnderElevation: 0,
      appBarBackgroundSchemeColor: SchemeColor.surface,
      appBarForegroundSchemeColor: SchemeColor.onSurface,
      
      // Navigation theme
      navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
      navigationBarSelectedIconSchemeColor: SchemeColor.primary,
      navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
      navigationBarElevation: 0,
      
      // Other settings
      blendOnLevel: 5,
      blendOnColors: false,
      useMaterial3Typography: true,
      useM2StyleDividerInM3: false,
      defaultRadius: 14.0,
      
      // Switch theme
      switchThumbSchemeColor: SchemeColor.surface,
      
      // Chip theme
      chipRadius: 20.0,
      chipSchemeColor: SchemeColor.primaryContainer,
      
      // Dialog theme
      dialogRadius: 20.0,
      dialogElevation: 0,
    ),
    fontFamily: GoogleFonts.inter().fontFamily,
    visualDensity: FlexColorScheme.comfortablePlatformDensity,
    useMaterial3: true,
    swapLegacyOnMaterial3: true,
  ).copyWith(
    // Custom enhancements untuk dark mode iOS style
    dividerTheme: const DividerThemeData(
      thickness: 0.5,
      space: 0.5,
      color: Color(0xFF38383A), // iOS System Gray 2 (dark)
    ),
    scaffoldBackgroundColor: const Color(0xFF000000), // iOS true black
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: const Color(0xFF38383A), // iOS System Gray 2 (dark)
          width: 0.5,
        ),
      ),
      color: const Color(0xFF1C1C1E), // iOS System Gray (dark)
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
    ),
    // Custom input decoration theme untuk dark mode
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Lebih compact
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: const Color(0xFF48484A), // iOS System Gray 2 (dark)
          width: 0.8,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(
          color: const Color(0xFF48484A), // iOS System Gray 2 (dark)
          width: 0.8,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Color(0xFF0A84FF), // iOS Blue (dark mode)
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Color(0xFFFF453A), // iOS Red (dark mode)
          width: 1.5,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(
          color: Color(0xFFFF453A), // iOS Red (dark mode)
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFF2C2C2E), // iOS System Gray yang lebih terang untuk dark mode
      hintStyle: TextStyle(
        color: const Color(0xFF8E8E93), // iOS System Gray
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: TextStyle(
        color: const Color(0xFF8E8E93), // iOS System Gray
        fontSize: 16.0,
        fontWeight: FontWeight.w400,
      ),
      floatingLabelStyle: TextStyle(
        color: const Color(0xFF0A84FF), // iOS Blue (dark mode)
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
  
  // iOS-inspired gradients
  static LinearGradient get iOSBlueGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF007AFF),
      Color(0xFF0051D5),
    ],
  );
  
  static LinearGradient get iOSGreenGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF34C759),
      Color(0xFF248A3D),
    ],
  );
  
  // iOS-style shadows (sangat subtle)
  static List<BoxShadow> get iOSCardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get iOSButtonShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
  
  // iOS System Colors
  static const Color iOSSystemBlue = Color(0xFF007AFF);
  static const Color iOSSystemGreen = Color(0xFF34C759);
  static const Color iOSSystemIndigo = Color(0xFF5856D6);
  static const Color iOSSystemOrange = Color(0xFFFF9500);
  static const Color iOSSystemPink = Color(0xFFFF2D92);
  static const Color iOSSystemPurple = Color(0xFFAF52DE);
  static const Color iOSSystemRed = Color(0xFFFF3B30);
  static const Color iOSSystemTeal = Color(0xFF5AC8FA);
  static const Color iOSSystemYellow = Color(0xFFFFCC00);
  
  // iOS System Grays
  static const Color iOSSystemGray = Color(0xFF8E8E93);
  static const Color iOSSystemGray2 = Color(0xFFAEAEB2);
  static const Color iOSSystemGray3 = Color(0xFFC7C7CC);
  static const Color iOSSystemGray4 = Color(0xFFD1D1D6);
  static const Color iOSSystemGray5 = Color(0xFFE5E5EA);
  static const Color iOSSystemGray6 = Color(0xFFF2F2F7);
}
