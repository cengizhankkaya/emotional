import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final class ApplicationTheme {
  ApplicationTheme.build(BuildContext context) {
    final theme = ThemeData.light(useMaterial3: true);
    final textTheme = theme.textTheme;
    themeData = theme.copyWith(
      timePickerTheme: const TimePickerThemeData(
        hourMinuteTextColor: Colors.black,
        hourMinuteColor: ColorsCustom.softGray,
        dayPeriodColor: Colors.black,
        dialHandColor: Colors.black,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: ColorsCustom.white),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ColorsCustom.white,
      ),
      scaffoldBackgroundColor: ColorsCustom.white,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        foregroundColor: ColorsCustom.darkBlue,
        backgroundColor: ColorsCustom.white,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: ColorsCustom.darkBlue),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        color: ColorsCustom.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        scrolledUnderElevation: 0,
        foregroundColor: ColorsCustom.white,
        backgroundColor: ColorsCustom.white,
        titleTextStyle: TextStyle(
          color: ColorsCustom.darkBlue,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: ColorsCustom.darkBlue),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(textTheme).copyWith(),
      colorScheme: theme.colorScheme.copyWith(
        primary: ColorsCustom.darkBlue,
        secondary: ColorsCustom.white,
        onPrimaryContainer: ColorsCustom.lightGray,
        onPrimaryFixed: ColorsCustom.gray,
        error: ColorsCustom.imperilRead,
        primaryContainer: ColorsCustom.skyBlue,
        onTertiaryContainer: ColorsCustom.cream,
        onSecondaryContainer: ColorsCustom.skyBlue,
        onSecondaryFixed: ColorsCustom.warmGrey,
        onPrimaryFixedVariant: ColorsCustom.darkGray,
        onTertiaryFixedVariant: ColorsCustom.cream,
      ),
      listTileTheme: const ListTileThemeData(
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Colors.black,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ColorsCustom.black,
        contentTextStyle: TextStyle(color: ColorsCustom.white),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(1.0),
      ),
    );
  }
  late final ThemeData themeData;
}
