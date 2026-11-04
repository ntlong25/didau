import 'package:flutter/material.dart';

/// Design tokens for Đi Đâu: warm paper background, deep lagoon green for
/// actions, terracotta for highlights. Every screen reads colors from here.
class AppColors {
  static const ink = Color(0xff1d2a27);
  static const muted = Color(0xff5f6b67);
  static const faint = Color(0xff6b756f);
  static const faintDecor = Color(0xff8a948f); // decorative icons/dividers only, never text
  static const paper = Color(0xfff7f3ea);
  static const surface = Colors.white;
  static const line = Color(0xffe6dfd1);
  static const lagoon = Color(0xff0f6b5c);
  static const lagoonDeep = Color(0xff0a4a40);
  static const lagoonSoft = Color(0xffdcefe9);
  static const terracotta = Color(0xffd0633f);
  static const terracottaInk = Color(0xffa8472a); // terracotta for text or under white text
  static const terracottaSoft = Color(0xfffbe6dc);
  static const sun = Color(0xfff2b544);
  static const sunLight = Color(0xffffd27a);
  static const open = Color(0xff2e7d4f);
  static const closed = Color(0xffb3402a);
}

class AppSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 24.0, xxl = 32.0;
  static const page = EdgeInsets.fromLTRB(20, 8, 20, 32);
}

class AppRadius {
  static const card = 20.0, chip = 14.0, button = 16.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lagoon,
    primary: AppColors.lagoon,
    onPrimary: Colors.white,
    secondary: AppColors.terracotta,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
  );
  const base = TextStyle(fontFamily: 'RobotoLocal', color: AppColors.ink);
  final text = TextTheme(
    displaySmall: base.copyWith(fontSize: 32, height: 1.15, fontWeight: FontWeight.w500, letterSpacing: -0.6),
    headlineSmall: base.copyWith(fontSize: 24, height: 1.2, fontWeight: FontWeight.w500, letterSpacing: -0.3),
    titleLarge: base.copyWith(fontSize: 19, height: 1.25, fontWeight: FontWeight.w500),
    titleMedium: base.copyWith(fontSize: 16, height: 1.3, fontWeight: FontWeight.w500),
    bodyLarge: base.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: base.copyWith(fontSize: 14.5, height: 1.45, color: AppColors.muted),
    bodySmall: base.copyWith(fontSize: 12.5, height: 1.4, color: AppColors.faint),
    labelLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.1),
    labelMedium: base.copyWith(fontSize: 12.5, fontWeight: FontWeight.w500, letterSpacing: 0.4, color: AppColors.muted),
  );
  final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button));
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'RobotoLocal',
    colorScheme: scheme,
    textTheme: text,
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: buttonShape,
        textStyle: text.labelLarge,
        disabledBackgroundColor: const Color(0xffd5dfdb),
        disabledForegroundColor: AppColors.muted,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        shape: buttonShape,
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line, width: 1.2),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 44), textStyle: text.labelLarge),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.faint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        borderSide: const BorderSide(color: AppColors.lagoon, width: 1.6),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.lagoon,
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.chip)),
      labelStyle: text.labelLarge,
      secondaryLabelStyle: text.labelLarge?.copyWith(color: Colors.white),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.lagoonSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelMedium?.copyWith(
          color: s.contains(WidgetState.selected) ? AppColors.lagoonDeep : AppColors.muted,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1),
  );
}
