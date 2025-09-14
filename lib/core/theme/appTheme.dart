import 'package:flutter/material.dart';

ThemeData getTheme(context) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.light,
    ),
    useMaterial3: true,
    // textTheme: customTextTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      elevation: 4.0,
      // titleTextStyle: customTextTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
    ),
    cardTheme: CardThemeData(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      shadowColor: Theme.of(context).colorScheme.shadow.withOpacity(0.2),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      tileColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      // titleTextStyle: customTextTheme.titleMedium,
      // subtitleTextStyle: customTextTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2.0),
      ),
      // labelStyle: customTextTheme.bodyMedium,
      // hintStyle: customTextTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      prefixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      suffixIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(50), // Make button wider
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        // textStyle: customTextTheme.labelLarge?.copyWith(fontSize: 18),
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 24.0),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        // textStyle: customTextTheme.labelLarge,
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      // titleTextStyle: customTextTheme.titleMedium,
      // contentTextStyle: customTextTheme.bodyMedium,
    ),
  );
}
        