import 'package:emotional/core/bloc/network/network_bloc.dart';
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
    final label = _getQualityLabel(state);

    return Tooltip(
      message: 'İnternet: $label',
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
          color: color.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
      return 'STABLE';
    case NetworkQuality.good:
      return 'UNCERTAIN';
    case NetworkQuality.poor:
      return 'LAGGING';
    case NetworkQuality.disconnected:
      return 'OFFLINE';
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
