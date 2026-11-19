import 'package:intl/intl.dart';

/// Utilidades de formateo para moneda colombiana (COP) y duraciones.
abstract final class AppFormatters {
  static final NumberFormat _copFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: r'$',
    decimalDigits: 0,
  );

  static String currency(num amount) => _copFormat.format(amount);

  static String minutesToHoursLabel(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}
