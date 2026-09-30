import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Единая точка правды по внешнему виду.
class AppTheme {
  static const _accent = Color(0xFF007AFF); // системный синий

  static ThemeData light() => _build(Brightness.light, const Color(0xFFF5F5F7));
  static ThemeData dark()  => _build(Brightness.dark,  const Color(0xFF1C1C1E));

  static ThemeData _build(Brightness brightness, Color background) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _accent, brightness: brightness),
      scaffoldBackgroundColor: background,
      // Только имя семейства — строка, без TextTheme, поэтому конфликта типов нет.
      fontFamily: GoogleFonts.inter().fontFamily,
    );
  }
}