import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioSessionService {
  AudioSession? _session;
  StreamSubscription<AudioInterruptionEvent>? _interruptionSubscription;
  StreamSubscription<AudioDevicesChangedEvent>? _deviceChangeSubscription;

  // Configuration for Voice Chat
  // This configuration ensures echo cancellation, noise suppression, and proper routing.
  static final AudioSessionConfiguration _voiceChatConfig =
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      );

  /// initializes and activates the audio session for a call.
  Future<void> activate() async {
    try {
      _session = await AudioSession.instance;
      await _session!.configure(_voiceChatConfig);

      // Listen to interruptions (e.g. phone call)
      _interruptionSubscription = _session!.interruptionEventStream.listen((
        event,
      ) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Another app lowered our volume (e.g. notification).
              // For voice chat, we usually ignore or maybe lower local stream volume?
              // WebRTC handles ducking automatically usually.
              debugPrint("Audio Session Ducked");
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Phone call or alarm. We should pause transmission.
              debugPrint("Audio Session Interrupted (Pause/Unknown)");
              // TODO: Notify Bloc to mute/hold call if needed.
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              debugPrint("Audio Session Unducked");
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              debugPrint("Audio Session Resumed from Interruption");
              // Consider reactivating session if OS didn't do it.
              try {
                _session?.setActive(true);
              } catch (e) {
                debugPrint("Error reactivating session: $e");
              }
              break;
          }
        }
      });

      // Listen to device changes (unplugging headphones)
      _deviceChangeSubscription = _session!.devicesChangedEventStream.listen((
        event,
      ) {
        debugPrint("Audio Devices Changed");
        // Session usually handles routing automatically given the configuration,
        // but we can enforce logic here if needed.
      });

      if (await _session!.setActive(true)) {
        debugPrint("Audio Session Activated for Voice Chat");
      } else {
        debugPrint("Audio Session Activation Failed");
      }
    } catch (e) {
      debugPrint("Error initializing AudioSessionService: $e");
    }
  }

  /// Deactivates the session, returning control to other apps (music etc.)
  Future<void> deactivate() async {
    await _interruptionSubscription?.cancel();
    _interruptionSubscription = null;
    await _deviceChangeSubscription?.cancel();
    _deviceChangeSubscription = null;

    try {
      await _session?.setActive(false);
    } catch (e) {
      debugPrint("Error deactivating session: $e");
    }
    _session = null;
  }
}
