import 'package:emotional/core/bloc/network/network_bloc.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class NetworkStatusHeader extends StatelessWidget {
  final Widget? child;
  final bool isIconOnly;

  const NetworkStatusHeader({super.key, this.child, this.isIconOnly = false});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkBloc, NetworkState>(
      builder: (context, state) {
        if (isIconOnly) {
          return _NetworkQualityIcon(state: state);
        }

        final isExcellent =
            state.quality == NetworkQuality.excellent && state.hasInternet;

        return Column(
          children: [
            if (!isExcellent) _DiscordStyleStatusHeader(state: state),
            if (child != null) Expanded(child: child!),
          ],
        );
      },
    );
  }
}

class _NetworkQualityIcon extends StatelessWidget {
  final NetworkState state;

  const _NetworkQualityIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = _getQualityColor(state);
    final icon = _getQualityIcon(state);

    return GestureDetector(
      onTap: () => _showNetworkDetailCard(context, state),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Icon(
          icon,
          key: ValueKey(icon.codePoint),
          color: color,
          size: 18,
        ),
      ),
    );
  }

  void _showNetworkDetailCard(BuildContext context, NetworkState state) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return BlocBuilder<NetworkBloc, NetworkState>(
          bloc: context.read<NetworkBloc>(),
          builder: (_, liveState) {
            final liveColor = _getQualityColor(liveState);
            final liveQualityText = _getQualityText(liveState);
            final liveIcon = _getQualityIcon(liveState);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 80,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2229),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: liveColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: liveColor.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: liveColor.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              liveIcon,
                              key: ValueKey(liveIcon.codePoint),
                              color: liveColor,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            liveQualityText,
                            style: TextStyle(
                              color: liveColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Details
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.circle,
                            iconColor: liveColor,
                            iconSize: 10,
                            label: 'Durum',
                            value: liveState.hasInternet
                                ? 'Çevrimiçi'
                                : 'Çevrimdışı',
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.speed_rounded,
                            iconColor: ColorsCustom.skyBlue,
                            label: 'Gecikme',
                            value: liveState.latencyMs > 0
                                ? '${liveState.latencyMs} ms'
                                : '—',
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.signal_cellular_alt_rounded,
                            iconColor: liveColor,
                            label: 'Kalite',
                            value: _getQualityLabel(liveState),
                          ),
                          const SizedBox(height: 14),
                          _DetailRow(
                            icon: Icons.access_time_rounded,
                            iconColor: Colors.white54,
                            label: 'Son Kontrol',
                            value: liveState.lastCheckedAt != null
                                ? _formatTime(liveState.lastCheckedAt!)
                                : '—',
                          ),
                          const SizedBox(height: 20),

                          // Latency bar
                          _LatencyBar(
                            latencyMs: liveState.latencyMs,
                            color: liveColor,
                          ),
                        ],
                      ),
                    ),

                    // Close button
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white54,
                        ),
                        child: const Text('Kapat'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    this.iconSize = 16,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _LatencyBar extends StatelessWidget {
  final int latencyMs;
  final Color color;

  const _LatencyBar({required this.latencyMs, required this.color});

  @override
  Widget build(BuildContext context) {
    // Normalize: 0ms = 0.0, 1000ms+ = 1.0
    final progress = latencyMs <= 0
        ? 0.0
        : (latencyMs / 1000.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gecikme Göstergesi',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            Text(
              latencyMs > 0 ? '${latencyMs}ms' : '—',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _DiscordStyleStatusHeader extends StatelessWidget {
  final NetworkState state;

  const _DiscordStyleStatusHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = _getQualityColor(state);
    final text = _getQualityText(state);
    final icon = _getQualityIcon(state);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 8),
                Text(
                  text.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Color _getQualityColor(NetworkState state) {
  if (!state.hasInternet) return const Color(0xfff23f43);
  switch (state.quality) {
    case NetworkQuality.excellent:
      return const Color(0xff23a559);
    case NetworkQuality.good:
      return const Color(0xfff0b232);
    case NetworkQuality.poor:
      return const Color(0xfff23f43);
    case NetworkQuality.disconnected:
      return const Color(0xfff23f43);
  }
}

String _getQualityText(NetworkState state) {
  if (!state.hasInternet) return 'BAĞLANTI YOK';
  switch (state.quality) {
    case NetworkQuality.excellent:
      return 'BAĞLANTI GÜÇLÜ';
    case NetworkQuality.good:
      return 'BAĞLANTI KARARSIZ';
    case NetworkQuality.poor:
      return 'BAĞLANTI ZAYIF';
    case NetworkQuality.disconnected:
      return 'BAĞLANTI KESİLDİ';
  }
}

String _getQualityLabel(NetworkState state) {
  if (!state.hasInternet) return 'OFFLINE';
  switch (state.quality) {
    case NetworkQuality.excellent:
      return 'Mükemmel';
    case NetworkQuality.good:
      return 'Orta';
    case NetworkQuality.poor:
      return 'Zayıf';
    case NetworkQuality.disconnected:
      return 'Bağlantı Yok';
  }
}

IconData _getQualityIcon(NetworkState state) {
  if (!state.hasInternet) return Icons.wifi_off_rounded;
  switch (state.quality) {
    case NetworkQuality.excellent:
      return Icons.signal_cellular_alt_rounded;
    case NetworkQuality.good:
      return Icons.signal_cellular_alt_2_bar_rounded;
    case NetworkQuality.poor:
      return Icons.signal_cellular_connected_no_internet_4_bar_rounded;
    case NetworkQuality.disconnected:
      return Icons.wifi_off_rounded;
  }
}
