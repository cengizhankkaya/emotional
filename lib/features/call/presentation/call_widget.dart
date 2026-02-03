import 'package:emotional/features/call/bloc/call_bloc.dart';
import 'package:emotional/features/call/bloc/call_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:emotional/features/call/domain/enums/call_video_size.dart';

class CallWidget extends StatefulWidget {
  const CallWidget({super.key});

  @override
  State<CallWidget> createState() => _CallWidgetState();
}

class _CallWidgetState extends State<CallWidget> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CallBloc, CallState>(
      builder: (context, state) {
        if (state is CallConnected) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 76,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: state.activeUsers.length,
                itemBuilder: (context, index) {
                  final entries = state.activeUsers.entries.toList();
                  final userId = entries[index].key;
                  final userName = entries[index].value;

                  if (userId == context.read<CallBloc>().userId) {
                    return const SizedBox.shrink();
                  }
                  final renderer = state.remoteRenderers[userId];
                  final hasVideo = state.userVideoStates[userId] ?? false;

                  return _buildMiniCameraItem(
                    name: userName,
                    isLocal: false,
                    hasVideo: hasVideo,
                    renderer: renderer,
                  );
                },
              ),
            ),
          );
        }
        if (state is CallLoading) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMiniCameraItem({
    required String name,
    required bool isLocal,
    required bool hasVideo,
    RTCVideoRenderer? renderer,
  }) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: hasVideo && renderer != null
            ? RTCVideoView(
                renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: isLocal,
              )
            : Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
      ),
    );
  }
}
