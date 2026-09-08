import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class VioClassConnectivityService extends ChangeNotifier
    with WidgetsBindingObserver {
  static final VioClassConnectivityService instance =
      VioClassConnectivityService._(
        Connectivity(),
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 2),
            validateStatus: (_) => true,
          ),
        ),
      );

  final Connectivity _connectivity;
  final Dio _probeClient;
  final StreamController<VioClassConnectivitySnapshot> _restoredController =
      StreamController<VioClassConnectivitySnapshot>.broadcast();
  final StreamController<VioClassConnectivitySnapshot> _lostController =
      StreamController<VioClassConnectivitySnapshot>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  VioClassConnectivitySnapshot _snapshot =
      VioClassConnectivitySnapshot.initial();
  String? _lastError;
  int _probeGeneration = 0;
  VioClassConnectivityService._(this._connectivity, this._probeClient);

  VioClassConnectivitySnapshot get snapshot => _snapshot;
  bool get initialized => _snapshot.initialized;
  bool get hasNetworkInterface => _snapshot.hasNetworkInterface;
  bool get hasInternetAccess => _snapshot.hasInternetAccess;
  bool get monitoring => _subscription != null;
  String? get lastError => _lastError;
  Stream<VioClassConnectivitySnapshot> get onNetworkRestored =>
      _restoredController.stream;
  Stream<VioClassConnectivitySnapshot> get onNetworkLost =>
      _lostController.stream;

  Future<void> start() async {
    if (monitoring) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _connectivity.onConnectivityChanged.listen(
      _applyResults,
      onError: _handleError,
    );
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _applyResults(results);
    } catch (error) {
      _handleError(error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refresh());
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    final recoveredFromError = _lastError != null;
    _lastError = null;
    final transports = results
        .where((result) => result != ConnectivityResult.none)
        .toSet();
    final previous = _snapshot;
    final transportChanged = !setEquals(previous.transports, transports);
    final generation = ++_probeGeneration;

    if (transports.isEmpty) {
      final wasAvailable = previous.initialized && previous.hasInternetAccess;
      _snapshot = VioClassConnectivitySnapshot(
        initialized: true,
        transports: const <ConnectivityResult>{},
        internetReachable: false,
        changedAt: DateTime.now(),
      );
      notifyListeners();
      if (wasAvailable) _lostController.add(_snapshot);
      return;
    }

    final shouldRestartConnections =
        previous.initialized &&
        (transportChanged || !previous.hasInternetAccess);
    if (transportChanged && previous.hasInternetAccess) {
      _lostController.add(
        VioClassConnectivitySnapshot(
          initialized: true,
          transports: previous.transports,
          internetReachable: false,
          changedAt: DateTime.now(),
        ),
      );
    }
    _snapshot = VioClassConnectivitySnapshot(
      initialized: true,
      transports: Set<ConnectivityResult>.unmodifiable(transports),
      internetReachable: transportChanged ? false : previous.internetReachable,
      changedAt: DateTime.now(),
    );
    if (transportChanged || recoveredFromError) notifyListeners();
    unawaited(
      _verifyTwitchReachability(
        generation: generation,
        emitRestored: shouldRestartConnections,
      ),
    );
  }

  Future<void> _verifyTwitchReachability({
    required int generation,
    required bool emitRestored,
  }) async {
    for (var attempt = 0; attempt < 6; attempt++) {
      if (generation != _probeGeneration || !_snapshot.hasNetworkInterface) {
        return;
      }
      if (await _canReachTwitch()) {
        if (generation != _probeGeneration) return;
        final wasReachable = _snapshot.hasInternetAccess;
        _snapshot = _snapshot.copyWith(
          internetReachable: true,
          changedAt: DateTime.now(),
        );
        if (!wasReachable) notifyListeners();
        if (emitRestored && !wasReachable) {
          _restoredController.add(_snapshot);
        }
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    if (generation != _probeGeneration) return;
    final wasReachable = _snapshot.hasInternetAccess;
    _snapshot = _snapshot.copyWith(
      internetReachable: false,
      changedAt: DateTime.now(),
    );
    if (wasReachable) {
      notifyListeners();
      _lostController.add(_snapshot);
    }
  }

  Future<bool> _canReachTwitch() async {
    try {
      final response = await _probeClient.head<Object>(
        'https://www.twitch.tv/',
        options: Options(followRedirects: false),
      );
      return response.statusCode != null;
    } catch (error) {
      return error is DioException && error.response?.statusCode != null;
    }
  }

  void _handleError(Object error) {
    final message = error.toString();
    if (_lastError == message) return;
    _lastError = message;
    notifyListeners();
  }
}

class VioClassConnectivitySnapshot {
  final bool initialized;
  final Set<ConnectivityResult> transports;
  final bool internetReachable;
  final DateTime? changedAt;

  const VioClassConnectivitySnapshot({
    required this.initialized,
    required this.transports,
    required this.internetReachable,
    required this.changedAt,
  });

  factory VioClassConnectivitySnapshot.initial() {
    return const VioClassConnectivitySnapshot(
      initialized: false,
      transports: <ConnectivityResult>{},
      internetReachable: false,
      changedAt: null,
    );
  }

  bool get hasNetworkInterface => transports.isNotEmpty;
  bool get hasInternetAccess => hasNetworkInterface && internetReachable;

  VioClassConnectivitySnapshot copyWith({
    bool? internetReachable,
    DateTime? changedAt,
  }) {
    return VioClassConnectivitySnapshot(
      initialized: initialized,
      transports: transports,
      internetReachable: internetReachable ?? this.internetReachable,
      changedAt: changedAt ?? this.changedAt,
    );
  }
}
