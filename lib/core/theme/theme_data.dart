import 'package:flutter/material.dart';
import 'app_color.dart';

// ThemeData must NOT reference AppSizes / ScreenUtil because ThemeData is
// constructed as a top-level global — ScreenUtilInit may not have run yet.
// Use raw design-size values (375×812 dp) here; ScreenUtil scaling belongs
// exclusively in widget build() methods.

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  extensions: const [AppColors.dark],
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryColor,
    surface: AppColors.dark.cardBackground,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.dark.scaffoldBackground,
  primaryColor: AppColors.primaryColor,

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.dark.scaffoldBackground,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.dark.textPrimary,
    ),
    iconTheme: IconThemeData(color: AppColors.dark.textPrimary),
  ),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonBackground,
      foregroundColor: AppColors.buttonText,
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),

  textButtonTheme: const TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(AppColors.primaryColor),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(
      color: AppColors.dark.hintText,
      fontSize: 14,
    ),
    filled: true,
    fillColor: AppColors.dark.inputFill,
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.inputFocusBorder, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.dark.inputBorder, width: 1),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.dark.inputBorder, width: 1),
    ),
    labelStyle: TextStyle(color: AppColors.dark.textSecondary),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.dark.bottomNavBackground,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppColors.primaryColor,
    unselectedItemColor: AppColors.dark.navUnselected,
    showUnselectedLabels: true,
    selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    unselectedLabelStyle: const TextStyle(fontSize: 10),
  ),

  cardTheme: CardThemeData(
    color: AppColors.dark.cardBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.dark.inputBorder, width: 1),
    ),
  ),

  dividerTheme: DividerThemeData(color: AppColors.dark.inputBorder, thickness: 1),

  textTheme: TextTheme(
    bodyLarge: TextStyle(color: AppColors.dark.textPrimary),
    bodyMedium: TextStyle(color: AppColors.dark.textSecondary),
    titleLarge: TextStyle(
      color: AppColors.dark.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  ),
);

ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const [AppColors.light],
  colorScheme: ColorScheme.light(
    primary: AppColors.primaryColor,
    surface: AppColors.light.cardBackground,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.light.scaffoldBackground,
  primaryColor: AppColors.primaryColor,

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.light.cardBackground,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.light.textPrimary,
    ),
    iconTheme: IconThemeData(color: AppColors.light.textPrimary),
  ),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonBackground,
      foregroundColor: AppColors.buttonText,
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      minimumSize: const Size.fromHeight(52),
    ),
  ),

  textButtonTheme: const TextButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll(AppColors.primaryColor),
    ),
  ),

  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(
      color: AppColors.light.hintText,
      fontSize: 14,
    ),
    filled: true,
    fillColor: AppColors.light.inputFill,
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.error, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.inputFocusBorder, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.light.inputBorder, width: 1),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.light.inputBorder, width: 1),
    ),
    labelStyle: TextStyle(color: AppColors.light.textSecondary),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.light.bottomNavBackground,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppColors.primaryColor,
    unselectedItemColor: AppColors.light.navUnselected,
    showUnselectedLabels: true,
    selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    unselectedLabelStyle: const TextStyle(fontSize: 10),
  ),

  cardTheme: CardThemeData(
    color: AppColors.light.cardBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.light.inputBorder, width: 1),
    ),
  ),

  dividerTheme: DividerThemeData(color: AppColors.light.inputBorder, thickness: 1),

  textTheme: TextTheme(
    bodyLarge: TextStyle(color: AppColors.light.textPrimary),
    bodyMedium: TextStyle(color: AppColors.light.textSecondary),
    titleLarge: TextStyle(
      color: AppColors.light.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  ),
);
