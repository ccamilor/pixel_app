/// Helper condicional: retorna (lat, lon) del GPS del navegador en Web, o null en otras plataformas.
Future<({double lat, double lon})?> getBrowserCoordinates() async => null;
