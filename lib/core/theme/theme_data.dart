import 'package:flutter/material.dart';
import '../constants/app_size.dart';
import 'app_color.dart';

ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryColor,
    surface: AppColors.cardBackground,
    error: AppColors.error,
  ),
  scaffoldBackgroundColor: AppColors.scaffoldBackground,
  primaryColor: AppColors.primaryColor,

  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.scaffoldBackground,
    elevation: 0,
    titleTextStyle: TextStyle(
      fontSize: AppSizes.sp16,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
  ),

  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: AppColors.primaryColor,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.buttonBackground,
      foregroundColor: AppColors.buttonText,
      textStyle: TextStyle(
        fontSize: AppSizes.sp16,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      minimumSize: Size.fromHeight(AppSizes.h52),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: AppColors.primaryColor),
  ),

  inputDecorationTheme: InputDecorationTheme(
    hintStyle: TextStyle(color: AppColors.hintText, fontSize: AppSizes.sp14),
    filled: true,
    fillColor: AppColors.inputFill,
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.error, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.inputFocusBorder, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.inputBorder, width: 1),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: AppColors.inputBorder, width: 1),
    ),
    labelStyle: TextStyle(color: AppColors.textSecondary),
  ),

  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.bottomNavBackground,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AppColors.primaryColor,
    unselectedItemColor: AppColors.navUnselected,
    showUnselectedLabels: true,
    selectedLabelStyle: TextStyle(
      fontSize: AppSizes.sp10,
      fontWeight: FontWeight.w600,
    ),
    unselectedLabelStyle: TextStyle(fontSize: AppSizes.sp10),
  ),

  cardTheme: CardThemeData(
    color: AppColors.cardBackground,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.inputBorder, width: 1),
    ),
  ),

  dividerTheme: DividerThemeData(color: AppColors.inputBorder, thickness: 1),

  textTheme: TextTheme(
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodyMedium: TextStyle(color: AppColors.textSecondary),
    titleLarge: TextStyle(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
  ),
);
