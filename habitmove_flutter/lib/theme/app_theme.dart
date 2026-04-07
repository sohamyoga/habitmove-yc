import 'package:flutter/material.dart';

// ─── Colour palette ──────────────────────────────────────────────────────────

class AppColors {
  AppColors._();

  // Sage greens (primary)
  static const sage50  = Color(0xFFF4F7F2);
  static const sage100 = Color(0xFFE2EBDD);
  static const sage200 = Color(0xFFC4D6BA);
  static const sage300 = Color(0xFF9AB88E);
  static const sage400 = Color(0xFF6F9661);
  static const sage500 = Color(0xFF4D7441);
  static const sage600 = Color(0xFF3A5A30);
  static const sage700 = Color(0xFF2E4726);
  static const sage800 = Color(0xFF25391E);
  static const sage900 = Color(0xFF1C2D18);

  // Warm ambers (accent)
  static const warm50  = Color(0xFFFDF8F0);
  static const warm100 = Color(0xFFFAEEDD);
  static const warm300 = Color(0xFFECBE72);
  static const warm400 = Color(0xFFE39F3A);
  static const warm500 = Color(0xFFD4821F);
  static const warm600 = Color(0xFFB56518);

  // Semantic
  static const error   = Color(0xFFDC2626);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFD97706);

  // Neutral
  static const white   = Color(0xFFFFFFFF);
  static const grey50  = Color(0xFFF9FAFB);
  static const grey200 = Color(0xFFE5E7EB);
  static const grey400 = Color(0xFF9CA3AF);
  static const grey600 = Color(0xFF4B5563);
}

// ─── Typography ──────────────────────────────────────────────────────────────

class AppTextStyles {
  AppTextStyles._();

  static const _serif = 'DMSerifDisplay';
  static const _sans  = 'DMSans';

  // Display
  static const displayLg = TextStyle(fontFamily: _serif, fontSize: 40, height: 1.1, color: AppColors.sage900);
  static const displayMd = TextStyle(fontFamily: _serif, fontSize: 32, height: 1.15, color: AppColors.sage900);
  static const displaySm = TextStyle(fontFamily: _serif, fontSize: 24, height: 1.2, color: AppColors.sage900);

  // Heading
  static const h1 = TextStyle(fontFamily: _sans, fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.sage900);
  static const h2 = TextStyle(fontFamily: _sans, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.sage900);
  static const h3 = TextStyle(fontFamily: _sans, fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.sage900);

  // Body
  static const bodyLg = TextStyle(fontFamily: _sans, fontSize: 16, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.sage800);
  static const body   = TextStyle(fontFamily: _sans, fontSize: 14, fontWeight: FontWeight.w400, height: 1.6, color: AppColors.sage700);
  static const bodySm = TextStyle(fontFamily: _sans, fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, color: AppColors.grey600);

  // Labels
  static const label     = TextStyle(fontFamily: _sans, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.sage500);
  static const labelDark = TextStyle(fontFamily: _sans, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.sage300);

  // Buttons
  static const button = TextStyle(fontFamily: _sans, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.2);
}

// ─── Theme ───────────────────────────────────────────────────────────────────

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sage600,
      primary: AppColors.sage700,
      secondary: AppColors.warm500,
      surface: AppColors.white,
      background: AppColors.sage50,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.sage50,
    fontFamily: 'DMSans',

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.sage900,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: AppColors.sage100,
      titleTextStyle: AppTextStyles.h2,
      centerTitle: false,
    ),

    cardTheme: CardTheme(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.sage100, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.sage700,
        foregroundColor: AppColors.white,
        textStyle: AppTextStyles.button,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.sage700,
        textStyle: AppTextStyles.button,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppColors.sage200),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.sage700,
        textStyle: AppTextStyles.button,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sage200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sage200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.sage500, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      labelStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.sage700,
      unselectedItemColor: AppColors.grey400,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontFamily: 'DMSans', fontSize: 11),
    ),

    dividerTheme: const DividerThemeData(color: AppColors.sage100, thickness: 1, space: 0),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.sage600),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.sage50,
      labelStyle: AppTextStyles.bodySm.copyWith(color: AppColors.sage700),
      side: const BorderSide(color: AppColors.sage200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),
  );
}
