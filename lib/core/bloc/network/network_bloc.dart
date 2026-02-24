import 'dart:async';
import 'dart:io';
import 'package:connectivity_watcher/connectivity_watcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// --- Events ---
abstract class NetworkEvent extends Equatable {
  const NetworkEvent();
  @override
  List<Object?> get props => [];
}

class NetworkStatusChanged extends NetworkEvent {
  final bool hasInternet;
  final NetworkQuality quality;
  final int latencyMs;

  const NetworkStatusChanged(this.hasInternet, this.quality, this.latencyMs);

  @override
  List<Object?> get props => [hasInternet, quality, latencyMs];
}

class _NetworkCheckRequested extends NetworkEvent {}

// --- States ---
enum NetworkQuality { excellent, good, poor, disconnected }

class NetworkState extends Equatable {
  final bool hasInternet;
  final NetworkQuality quality;
  final int latencyMs;
  final DateTime? lastCheckedAt;

  const NetworkState({
    this.hasInternet = true,
    this.quality = NetworkQuality.excellent,
    this.latencyMs = 0,
    this.lastCheckedAt,
  });

  @override
  List<Object?> get props => [hasInternet, quality, latencyMs, lastCheckedAt];

  NetworkState copyWith({
    bool? hasInternet,
    NetworkQuality? quality,
    int? latencyMs,
    DateTime? lastCheckedAt,
  }) {
    return NetworkState(
      hasInternet: hasInternet ?? this.hasInternet,
      quality: quality ?? this.quality,
      latencyMs: latencyMs ?? this.latencyMs,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    );
  }
}

// --- Bloc ---
class NetworkBloc extends Bloc<NetworkEvent, NetworkState>
    with WidgetsBindingObserver {
  final ZoConnectivityWatcher _watcher = ZoConnectivityWatcher();
  Timer? _qualityCheckTimer;

  NetworkBloc() : super(const NetworkState()) {
    WidgetsBinding.instance.addObserver(this);
    on<NetworkStatusChanged>((event, emit) {
      debugPrint(
        'NetworkBloc: State update - hasInternet: ${event.hasInternet}, '
        'Quality: ${event.quality}, Latency: ${event.latencyMs}ms',
      );
      emit(
        state.copyWith(
          hasInternet: event.hasInternet,
          quality: event.quality,
          latencyMs: event.latencyMs,
          lastCheckedAt: DateTime.now(),
        ),
      );
    });

    on<_NetworkCheckRequested>((event, emit) async {
      try {
        // First check via connectivity_watcher (fast, synchronous)
        final hasInternet = _watcher.isInternetAvailable;

        if (!hasInternet) {
          add(
            const NetworkStatusChanged(false, NetworkQuality.disconnected, 0),
          );
          return;
        }

        // Measure actual latency with an HTTP HEAD request
        final latencyMs = await _measureLatency();
        final quality = _qualityFromLatency(latencyMs);
        add(NetworkStatusChanged(true, quality, latencyMs));
      } catch (e) {
        debugPrint('NetworkBloc: Check error: $e');
        add(const NetworkStatusChanged(false, NetworkQuality.disconnected, 0));
      }
    });

    _init();
  }

  void _init() {
    debugPrint('NetworkBloc: Initializing connection monitors...');

    // Immediate initial check
    add(_NetworkCheckRequested());

    // Periodically check quality
    _qualityCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      add(_NetworkCheckRequested());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint(
        'NetworkBloc: App resumed, triggering immediate network check',
      );
      add(_NetworkCheckRequested());
    }
  }

  /// Measure real network latency by pinging Google's generate_204 endpoint
  Future<int> _measureLatency() async {
    try {
      final stopwatch = Stopwatch()..start();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final request = await client.headUrl(
        Uri.parse('https://www.google.com/generate_204'),
      );
      final response = await request.close();
      await response.drain();
      client.close(force: true);
      stopwatch.stop();

      final ms = stopwatch.elapsedMilliseconds;
      debugPrint('NetworkBloc: Latency ping took ${ms}ms');
      return ms;
    } catch (e) {
      debugPrint('NetworkBloc: Latency measurement error: $e');
      return -1; // Indicates failure
    }
  }

  NetworkQuality _qualityFromLatency(int ms) {
    if (ms < 0) return NetworkQuality.disconnected;
    if (ms < 250) return NetworkQuality.excellent;
    if (ms < 600) return NetworkQuality.good;
    return NetworkQuality.poor;
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _qualityCheckTimer?.cancel();
    return super.close();
  }
}
