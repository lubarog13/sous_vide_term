import 'package:flutter/material.dart';

final lightColorScheme = ColorScheme.fromSeed(
  seedColor: Color.fromARGB(255, 39, 191, 15),
  brightness: Brightness.light,
  primary: Color.fromARGB(255, 22, 140, 4),
  error: Color.fromARGB(255, 191, 83, 59),
  secondary: Color.fromARGB(255, 242, 212, 121),
  tertiary: Color.fromARGB(255, 59, 125, 191),
  tertiaryFixed: Color.fromARGB(255, 61, 85, 112),
  surface: Color.fromARGB(255, 242, 242, 242),
  secondaryContainer: Color.fromARGB(255, 255, 255, 255),
);

/// Same brand seed as light; tuned for contrast on dark surfaces.
final darkColorScheme = ColorScheme.fromSeed(
  seedColor: Color.fromARGB(255, 39, 191, 15),
  brightness: Brightness.dark,
  primary: Color.fromARGB(255, 118, 220, 96),
  onPrimary: Color.fromARGB(255, 12, 48, 8),
  secondary: Color.fromARGB(255, 215, 185, 95),
  onSecondary: Color.fromARGB(255, 40, 32, 8),
  error: Color.fromARGB(255, 255, 140, 120),
  onError: Color.fromARGB(255, 48, 16, 12),
  tertiary: Color.fromARGB(255, 59, 125, 191),
  surface: Color.fromARGB(255, 18, 20, 18),
  onSurface: Color.fromARGB(255, 230, 230, 228),
  secondaryContainer: Color.fromARGB(255, 25, 25, 25),
);