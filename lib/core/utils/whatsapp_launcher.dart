import 'package:url_launcher/url_launcher.dart';

import '../constants/app_enums.dart';
import 'formatters.dart';

/// Utilidades para abrir WhatsApp con plantillas automáticas según el estado del pedido.
abstract final class WhatsAppLauncher {
  /// Normaliza el teléfono eliminando espacios, guiones o símbolos no numéricos.
  static String sanitizePhone(String rawPhone, {String defaultCountryCode = '57'}) {
    final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.length == 10) return '$defaultCountryCode$digits';
    return digits;
  }

  /// Genera el mensaje prellenado según el estado actual del pedido.
  static String buildOrderMessage({
    required String clientName,
    required String orderTitle,
    required OrderStatus status,
    required double balanceDue,
  }) {
    final balanceText = AppFormatters.currency(balanceDue);
    return switch (status) {
      OrderStatus.pending =>
        'Hola $clientName, confirmamos recepción de tu pedido "$orderTitle". Pronto iniciamos el diseño.',
      OrderStatus.design =>
        'Hola $clientName, te envío el avance/boceto de tu pedido "$orderTitle" para tu aprobación antes de pasar a impresión.',
      OrderStatus.printing =>
        'Hola $clientName, tu pedido "$orderTitle" ya se encuentra en producción/impresión. Te avisamos apenas esté listo.',
      OrderStatus.ready =>
        balanceDue > 0
            ? 'Hola $clientName, tu pedido "$orderTitle" ya está listo para entrega. Saldo pendiente: $balanceText.'
            : 'Hola $clientName, tu pedido "$orderTitle" ya está listo para entrega (pagado en su totalidad).',
      OrderStatus.delivered =>
        'Hola $clientName, gracias por tu compra de "$orderTitle". ¡Cualquier ajuste o nuevo diseño quedamos atentos!',
    };
  }

  static Uri buildWhatsAppUri({
    required String phone,
    String? message,
  }) {
    final cleanPhone = sanitizePhone(phone);
    final encoded = message != null && message.isNotEmpty
        ? '?text=${Uri.encodeComponent(message)}'
        : '';
    return Uri.parse('https://wa.me/$cleanPhone$encoded');
  }

  static Future<bool> openChat({
    required String phone,
    String? message,
  }) async {
    final cleanPhone = sanitizePhone(phone);
    if (cleanPhone.isEmpty) return false;
    final uri = buildWhatsAppUri(phone: cleanPhone, message: message);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
