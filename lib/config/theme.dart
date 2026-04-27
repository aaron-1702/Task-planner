import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';

class AppTheme {
  AppTheme._();

  static const Color _primaryColor = Color(0xFF6366F1);       // Indigo
  static const Color _secondaryColor = Color(0xFF8B5CF6);     // Violet
  static const Color _tertiaryColor = Color(0xFF06B6D4);      // Cyan

  static const Color _errorColor = Color(0xFFEF4444);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);

  // Priority colors
  static const Color priorityLow = Color(0xFF10B981);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityHigh = Color(0xFFEF4444);

  // Status colors
  static const Color statusOpen = Color(0xFF6B7280);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusDone = Color(0xFF10B981);

  static TextTheme get _textTheme => GoogleFonts.interTextTheme();

  static ThemeData get lightTheme {
    final base = FlexThemeData.light(
      scheme: FlexScheme.indigo,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        inputDecoratorIsFilled: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorUnfocusedBorderIsColored: false,
        cardRadius: 16.0,
        chipRadius: 8.0,
        dialogRadius: 20.0,
        elevatedButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        filledButtonRadius: 12.0,
        textButtonRadius: 12.0,
        fabRadius: 16.0,
        bottomSheetRadius: 24.0,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarMutedUnselectedLabel: true,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarMutedUnselectedIcon: true,
        navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
        navigationBarIndicatorOpacity: 1.0,
        navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
        navigationRailMutedUnselectedLabel: true,
        navigationRailSelectedIconSchemeColor: SchemeColor.primary,
        navigationRailMutedUnselectedIcon: true,
        navigationRailIndicatorSchemeColor: SchemeColor.primaryContainer,
        navigationRailIndicatorOpacity: 1.0,
      ),
      keyColors: const FlexKeyColors(
        useSecondary: true,
        useTertiary: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: _textTheme.apply(
        bodyColor: base.colorScheme.onSurface,
        displayColor: base.colorScheme.onSurface,
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = FlexThemeData.dark(
      scheme: FlexScheme.indigo,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useTextTheme: true,
        useM2StyleDividerInM3: true,
        inputDecoratorIsFilled: true,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorUnfocusedBorderIsColored: false,
        cardRadius: 16.0,
        chipRadius: 8.0,
        dialogRadius: 20.0,
        elevatedButtonRadius: 12.0,
        outlinedButtonRadius: 12.0,
        filledButtonRadius: 12.0,
        textButtonRadius: 12.0,
        fabRadius: 16.0,
        bottomSheetRadius: 24.0,
        navigationBarSelectedLabelSchemeColor: SchemeColor.primary,
        navigationBarMutedUnselectedLabel: true,
        navigationBarSelectedIconSchemeColor: SchemeColor.primary,
        navigationBarMutedUnselectedIcon: true,
        navigationBarIndicatorSchemeColor: SchemeColor.primaryContainer,
        navigationBarIndicatorOpacity: 1.0,
        navigationRailSelectedLabelSchemeColor: SchemeColor.primary,
        navigationRailMutedUnselectedLabel: true,
        navigationRailSelectedIconSchemeColor: SchemeColor.primary,
        navigationRailMutedUnselectedIcon: true,
        navigationRailIndicatorSchemeColor: SchemeColor.primaryContainer,
        navigationRailIndicatorOpacity: 1.0,
      ),
      keyColors: const FlexKeyColors(
        useSecondary: true,
        useTertiary: true,
      ),
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      useMaterial3: true,
    );
    return base.copyWith(
      textTheme: _textTheme.apply(
        bodyColor: base.colorScheme.onSurface,
        displayColor: base.colorScheme.onSurface,
      ),
    );
  }
}
