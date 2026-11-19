import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Verifica y emite el estado de conectividad de red (compatible con Android y Web).
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Future<bool> get hasConnection async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  Stream<bool> get onStatusChanged {
    return _connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

final isOnlineProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.onStatusChanged;
});
