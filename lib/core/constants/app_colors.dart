import 'package:material_ui/material_ui.dart';

/// Paleta OLED de App Pixel: negro puro (#000000) con azules profundos y cianes vibrantes.
abstract final class AppColors {
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0A0A0A);
  static const Color surfaceElevated = Color(0xFF111111);
  static const Color border = Color(0xFF1E293B);

  static const Color primaryDeepBlue = Color(0xFF0D47A1);
  static const Color primaryBlue = Color(0xFF1565C0);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentCyanMuted = Color(0xFF00B8D4);

  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  static const Color success = Color(0xFF00E676);
  static const Color warning = Color(0xFFFFAB00);
  static const Color error = Color(0xFFFF5252);

  /// Niveles de intensidad para el Mapa de Calor estilo GitHub (0 a 4).
  static const List<Color> heatmapScale = [
    Color(0xFF0A0A0A),
    primaryDeepBlue,
    primaryBlue,
    accentCyanMuted,
    accentCyan,
  ];
}
