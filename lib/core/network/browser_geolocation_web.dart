import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Obtiene las coordenadas exactas (GPS/Wi-Fi) desde `navigator.geolocation` en Flutter Web.
Future<({double lat, double lon})?> getBrowserCoordinates() {
  final completer = Completer<({double lat, double lon})?>();

  try {
    final geo = web.window.navigator.geolocation;
    geo.getCurrentPosition(
      ((web.GeolocationPosition pos) {
        if (!completer.isCompleted) {
          completer.complete((
            lat: pos.coords.latitude.toDouble(),
            lon: pos.coords.longitude.toDouble(),
          ));
        }
      }).toJS,
      ((web.GeolocationPositionError _) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 6000,
        maximumAge: 300000,
      ),
    );
  } catch (_) {
    if (!completer.isCompleted) {
      completer.complete(null);
    }
  }

  return completer.future.timeout(
    const Duration(seconds: 7),
    onTimeout: () => null,
  );
}
