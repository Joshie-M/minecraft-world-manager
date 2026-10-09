import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared dimensions; mobile keeps a minimum 44 px touch target.
abstract final class DesignTokens {
  static const sidebarWidth = 216.0;
  static const desktopBreakpoint = 900.0;
  static const radius = 8.0;
  static const contentInset = 24.0;
  static bool get isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    _ => false,
  };
}

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final apple =
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final surface = Color(dark ? 0xff202124 : 0xffffffff);
  final secondary = Color(dark ? 0xff28292d : 0xfff3f3f5);
  final border = Color(dark ? 0xff424348 : 0xffe3e3e8);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xff356ad8),
    brightness: brightness,
    surface: surface,
    surfaceContainerLow: secondary,
    primary: Color(dark ? 0xff8eb5ff : 0xff285ec5),
    onPrimary: dark ? const Color(0xff13284b) : Colors.white,
    onSurface: Color(dark ? 0xffefeff2 : 0xff242428),
    onSurfaceVariant: Color(dark ? 0xffb5b5bd : 0xff64646e),
    outlineVariant: border,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: apple
        ? const CupertinoThemeData().textTheme.textStyle.fontFamily
        : defaultTargetPlatform == TargetPlatform.windows
        ? 'Segoe UI'
        : null,
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(DesignTokens.radius),
  );
  final height = DesignTokens.isDesktop ? 32.0 : 44.0;
  return base.copyWith(
    scaffoldBackgroundColor: surface,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: scheme.onSurface.withValues(alpha: .045),
    textTheme: base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontFamily: base.textTheme.bodyMedium?.fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -.5,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontFamily: base.textTheme.bodyMedium?.fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -.3,
        color: scheme.onSurface,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.5),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.4,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
    iconTheme: IconThemeData(size: 18, color: scheme.onSurfaceVariant),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        side: BorderSide.none,
        backgroundColor: secondary,
        foregroundColor: scheme.onSurface,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: shape,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: secondary,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: .5, space: 1),
  );
}
