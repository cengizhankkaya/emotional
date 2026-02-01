import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class IMediaDeviceService {
  /// Initialize media devices (request permissions, get initial stream)
  Future<void> initialize({
    CallQualityPreset quality = CallQualityPreset.balanced,
  });

  /// Get the current local media stream
  MediaStream? get localStream;

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
  void toggleVideo(bool enabled);

  /// Toggle audio track enabled/disabled
  void toggleMute(bool muted); // muted=true -> enabled=false

  /// Change video quality preset at runtime
  Future<void> setQuality(CallQualityPreset preset);

  /// Switch between front/back camera (helper for mobile)
  Future<void> switchCamera();

  /// Enable/Disable speakerphone (Mobile specific)
  Future<void> enableSpeakerphone(bool enabled);

  /// Clean up resources
  Future<void> dispose();
}
