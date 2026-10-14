import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class IMediaDeviceService {
  /// Initialize media devices (request permissions, get initial stream)
  Future<void> initialize({
    CallQualityPreset quality = CallQualityPreset.balanced,
    bool enableVideo = true,
    bool enableAudio = true,
  });

  /// Get the current local media stream
  MediaStream? get localStream;

  /// Get the current screen share stream
  MediaStream? get screenStream;

  String? get selectedVideoDeviceId;
  String? get selectedAudioDeviceId;
  String? get selectedAudioOutputId;

  /// List available video input devices (Cameras)
  Future<List<MediaDeviceInfo>> getVideoInputs();

  /// List available audio input devices (Microphones)
  Future<List<MediaDeviceInfo>> getAudioInputs();

  /// List available audio output devices (Speakers/Headsets)
  Future<List<MediaDeviceInfo>> getAudioOutputs();

  /// Switch to a specific video input device
  Future<void> selectVideoInput(MediaDeviceInfo device);

  /// Switch to a specific audio input device
  Future<void> selectAudioInput(MediaDeviceInfo device);

  /// Switch to a specific audio output device
  Future<void> selectAudioOutput(MediaDeviceInfo device);

  /// Toggle video track enabled/disabled
  /// A device stopped on its own (unplugged, headset disconnected).
  void Function()? onMicrophoneLost;
  void Function()? onCameraLost;

  /// Switches to the default microphone; null if there is none.
  Future<MediaStreamTrack?> restartMicrophone();

  /// Opens the camera into the local stream; null if that isn't possible.
  Future<MediaStreamTrack?> startCamera();

  /// Releases the camera; the microphone keeps running.
  Future<void> stopCamera();

  void toggleVideo(bool enabled);

  /// Toggle audio track enabled/disabled
  void toggleMute(bool muted); // muted=true -> enabled=false

  /// Change video quality preset at runtime
  Future<void> setQuality(CallQualityPreset preset);

  /// Switch between front/back camera (helper for mobile)
  Future<void> switchCamera();

  /// Enable/Disable speakerphone (Mobile specific)
  Future<void> enableSpeakerphone(bool enabled);

  /// Start screen sharing. [options] tune the browser capture on web and are
  /// ignored on mobile.
  Future<void> startScreenShare({ScreenShareOptions? options});

  /// Stop screen sharing and revert to camera
  Future<void> stopScreenShare();

  /// Clean up resources
  Future<void> dispose();
}
