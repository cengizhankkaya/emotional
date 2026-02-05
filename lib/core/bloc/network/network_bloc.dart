import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

// --- Events ---
abstract class NetworkEvent extends Equatable {
  const NetworkEvent();
  @override
  List<Object?> get props => [];
}

class NetworkStatusChanged extends NetworkEvent {
  final List<ConnectivityResult> results;
  final bool hasInternet;
  final NetworkQuality quality;

  const NetworkStatusChanged(this.results, this.hasInternet, this.quality);

  @override
  List<Object?> get props => [results, hasInternet, quality];
}

class _NetworkQualityPingRequested extends NetworkEvent {}

// --- States ---
enum NetworkQuality { excellent, good, poor, disconnected }

class NetworkState extends Equatable {
  final List<ConnectivityResult> connectivityResults;
  final bool hasInternet;
  final NetworkQuality quality;

  const NetworkState({
    this.connectivityResults = const [],
    this.hasInternet = true,
    this.quality = NetworkQuality.excellent,
  });

  @override
  List<Object?> get props => [connectivityResults, hasInternet, quality];

  NetworkState copyWith({
    List<ConnectivityResult>? connectivityResults,
    bool? hasInternet,
    NetworkQuality? quality,
  }) {
    return NetworkState(
      connectivityResults: connectivityResults ?? this.connectivityResults,
      hasInternet: hasInternet ?? this.hasInternet,
      quality: quality ?? this.quality,
    );
  }
}

// --- Bloc ---
class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetChecker = InternetConnection();
  StreamSubscription? _connectivitySubscription;
  Timer? _qualityCheckTimer;

  NetworkBloc() : super(const NetworkState()) {
    on<NetworkStatusChanged>((event, emit) {
      debugPrint(
        'NetworkBloc: State update - hasInternet: ${event.hasInternet}, Quality: ${event.quality}',
      );
      emit(
        state.copyWith(
          connectivityResults: event.results,
          hasInternet: event.hasInternet,
          quality: event.quality,
        ),
      );
    });

    on<_NetworkQualityPingRequested>((event, emit) async {
      // Fetch results if they are still 'none' (initial state)
      List<ConnectivityResult> results = state.connectivityResults;
      if (results.isEmpty) {
        results = await _connectivity.checkConnectivity();
      }

      debugPrint('NetworkBloc: Connectivity results: $results');

      if (results.contains(ConnectivityResult.none)) {
        add(NetworkStatusChanged(results, false, NetworkQuality.disconnected));
        return;
      }

      try {
        final hasInternet = await _internetChecker.hasInternetAccess;
        debugPrint('NetworkBloc: hasInternetAccess check: $hasInternet');

        if (!hasInternet) {
          add(
            NetworkStatusChanged(results, false, NetworkQuality.disconnected),
          );
          return;
        }

        final quality = await _determineQuality();
        add(NetworkStatusChanged(results, true, quality));
      } catch (e) {
        debugPrint('NetworkBloc: Ping check error: $e');
        add(NetworkStatusChanged(results, false, NetworkQuality.disconnected));
      }
    });

    _init();
  }

  void _init() {
    debugPrint('NetworkBloc: Initializing connection monitors...');

    // Immediate initial check
    add(_NetworkQualityPingRequested());

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      debugPrint('NetworkBloc: Connectivity changed event: $results');
      add(_NetworkQualityPingRequested());
    });

    // Periodically check quality
    _qualityCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      add(_NetworkQualityPingRequested());
    });
  }

  Future<NetworkQuality> _determineQuality() async {
    try {
      final stopwatch = Stopwatch()..start();
      // Using a simple head request for more accurate latency measurement
      final hasAccess = await _internetChecker.hasInternetAccess;
      stopwatch.stop();

      final ms = stopwatch.elapsedMilliseconds;
      debugPrint('NetworkBloc: Latency check took ${ms}ms');

      if (!hasAccess) return NetworkQuality.disconnected;

      if (ms < 250) return NetworkQuality.excellent;
      if (ms < 600) return NetworkQuality.good;
      return NetworkQuality.poor;
    } catch (e) {
      debugPrint('NetworkBloc: _determineQuality error: $e');
      return NetworkQuality.disconnected;
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    _qualityCheckTimer?.cancel();
    return super.close();
  }
}
