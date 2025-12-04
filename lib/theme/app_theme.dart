// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Paleta
  static const _ink = Color(0xFF0E0E10);        // casi negro
  static const _ivory = Color(0xFFF7F7F5);     // blanco cálido
  static const _smoke = Color(0xFFEAEAE8);     // gris suave
  static const _charcoal = Color(0xFF232325);  // gris oscuro profundo
  static const _gold = Color(0xFFFFD400);      // acento “Glovo-ish”
  static const _mint = Color(0xFF10B981);      // verdecito sutil para estados OK
  static const _rose = Color(0xFFE11D48);      // acento error/alerta

  // ... imports y colores iguales

static ThemeData vogueGlovoLight = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color.fromARGB(255, 86, 149, 170),
    brightness: Brightness.light,
    primary: const Color.fromARGB(255, 86, 149, 170),
    onPrimary: _ink,
    secondary: _charcoal,
    onSecondary: _ivory,
    surface: _ivory,
    onSurface: _ink,
    background: _ivory,
    onBackground: _ink,
    error: _rose,
    onError: _ivory,
  ),
  scaffoldBackgroundColor: _ivory,

  appBarTheme: const AppBarTheme(
    backgroundColor: _ivory,
    foregroundColor: _ink,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontFamily: 'Serif',
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: -0.2,
      color: _ink,
    ),
  ),

  textTheme: const TextTheme(
    displayLarge: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.w800, letterSpacing: -1.0),
    displayMedium: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.w700, letterSpacing: -0.6),
    titleLarge: TextStyle(fontFamily: 'Serif', fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontWeight: FontWeight.w700),
    labelLarge: TextStyle(fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(height: 1.3),
    bodyMedium: TextStyle(height: 1.35),
  ),

  // ⬇️ Usa CardThemeData en lugar de CardTheme
  cardTheme: CardThemeData(
    color: Colors.white,
    margin: const EdgeInsets.all(0),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    surfaceTintColor: Colors.white,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _smoke),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _smoke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _gold, width: 1.4),
    ),
    hintStyle: const TextStyle(color: _charcoal),
  ),

  navigationBarTheme: NavigationBarThemeData(
    indicatorColor: _gold.withOpacity(0.18),
    backgroundColor: _ivory,
    // ⬇️ Usa MaterialStateProperty en lugar de WidgetStateProperty
    labelTextStyle: MaterialStateProperty.all(
      const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),

  chipTheme: ChipThemeData(
    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
    backgroundColor: _smoke,
    selectedColor: _gold.withOpacity(0.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  ),

  dividerTheme: const DividerThemeData(
    color: _smoke,
    thickness: 1,
    space: 24,
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _gold,
    foregroundColor: _ink,
    extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
  ),

  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      shape: MaterialStateProperty.all(const CircleBorder()),
      padding: MaterialStateProperty.all(const EdgeInsets.all(10)),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) return _gold.withOpacity(0.24);
        return Colors.transparent;
      }),
    ),
  ),
);

// —— Tema oscuro
static ThemeData vogueGlovoDark = vogueGlovoLight.copyWith(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: _ink,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _gold,
    brightness: Brightness.dark,
    primary: _gold,
    onPrimary: _ink,
    secondary: _ivory,
    onSecondary: _ink,
    surface: _charcoal,
    onSurface: _ivory,
    background: _ink,
    onBackground: _ivory,
    error: _rose,
    onError: _ivory,
  ),
  appBarTheme: const AppBarTheme(backgroundColor: _ink, foregroundColor: _ivory),

  // ⬇️ También CardThemeData aquí
  cardTheme: CardThemeData(
    color: _charcoal,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    elevation: 0,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: _charcoal,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _gold, width: 1.4),
    ),
  ),
);

  static var lightTheme;

}
