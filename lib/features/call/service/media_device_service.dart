import 'dart:async';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/services/i_media_device_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaDeviceService implements IMediaDeviceService {
  MediaStream? _localStream;
  CallQualityPreset _currentQuality = CallQualityPreset.balanced;

  // Keep track of selected devices to preserve selection during quality change
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;

  @override
  MediaStream? get localStream => _localStream;

  @override
  Future<void> initialize({
    CallQualityPreset quality = CallQualityPreset.balanced,
  }) async {
    _currentQuality = quality;

    try {
      await _tryStartStream(quality);
    } catch (e) {
      print(
        "CRITICAL: Failed to initialize media stream even after fallback: $e",
      );
      // Even if fallback fails, we might want to try AudioOnly as last resort
      // But _tryStartStream logic below should handle degradation.
    }

    // Default states
    toggleVideo(true);
    toggleMute(false);
  }

  /// Attempts to start the stream with the requested quality.
  /// If it fails due to OverconstrainedError or similar, it recursively tries lower qualities.
  Future<void> _tryStartStream(CallQualityPreset quality) async {
    print(
      "MediaDeviceService: Attempting to start stream with quality: ${quality.name}",
    );

    // Dispose previous if any
    if (_localStream != null) {
      await _localStream!.dispose();
      _localStream = null;
    }

    final videoConstraints = quality.toConstraints();

    // Applying device selection
    if (_selectedVideoDeviceId != null) {
      videoConstraints['deviceId'] = _selectedVideoDeviceId;
    } else {
      videoConstraints['facingMode'] = 'user';
    }

    // Google-tuned Audio Constraints
    final audioConstraints = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
      'googEchoCancellation': true,
      'googEchoCancellation2': true,
      'googAutoGainControl': true,
      'googNoiseSuppression': true,
      'googHighpassFilter': true,
    };

    if (_selectedAudioDeviceId != null) {
      audioConstraints['deviceId'] = _selectedAudioDeviceId;
    }

    final mediaConstraints = {
      'audio': audioConstraints,
      'video': videoConstraints,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _currentQuality = quality; // Success, update current quality
      print(
        "MediaDeviceService: Stream started successfully with ${quality.name}",
      );
    } catch (e) {
      print(
        "MediaDeviceService: Failed to start with ${quality.name}. Error: $e",
      );

      // Fallback Logic
      final nextQuality = _getNextLowerQuality(quality);
      if (nextQuality != null) {
        print(
          "MediaDeviceService: Fallback -> Retrying with ${nextQuality.name}",
        );
        await _tryStartStream(nextQuality);
      } else {
        // If lowest quality video also fails, try AUDIO ONLY as last resort
        print(
          "MediaDeviceService: All video qualities failed. Trying Audio Only.",
        );
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': audioConstraints,
            'video': false,
          });
          print("MediaDeviceService: Audio-only stream started.");
        } catch (audioError) {
          print("MediaDeviceService: Audio-only also failed. Giving up.");
          rethrow;
        }
      }
    }
  }

  CallQualityPreset? _getNextLowerQuality(CallQualityPreset current) {
    switch (current) {
      case CallQualityPreset.ultra:
        return CallQualityPreset.high;
      case CallQualityPreset.high:
        return CallQualityPreset.balanced;
      case CallQualityPreset.balanced:
        return CallQualityPreset.low;
      case CallQualityPreset.low:
        return null; // Initial fail was already low
    }
  }

  // Public Wrapper for changing quality manually
  @override
  Future<void> setQuality(CallQualityPreset preset) async {
    if (_currentQuality == preset) return;
    await _tryStartStream(preset);
  }

  // --- Standard Device Selection ---

  @override
  Future<List<MediaDeviceInfo>> getVideoInputs() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((d) => d.kind == 'videoinput').toList();
  }

  @override
  Future<List<MediaDeviceInfo>> getAudioInputs() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((d) => d.kind == 'audioinput').toList();
  }

  @override
  Future<List<MediaDeviceInfo>> getAudioOutputs() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    return devices.where((d) => d.kind == 'audiooutput').toList();
  }

  @override
  Future<void> selectVideoInput(MediaDeviceInfo device) async {
    _selectedVideoDeviceId = device.deviceId;
    await _tryStartStream(_currentQuality);
  }

  @override
  Future<void> selectAudioInput(MediaDeviceInfo device) async {
    _selectedAudioDeviceId = device.deviceId;
    await _tryStartStream(_currentQuality);
  }

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    try {
      // Helper.selectAudioOutput(device.deviceId);
      print("Mock: Selecting Audio Output ${device.label}");
    } catch (e) {
      print("Error selecting audio output: $e");
    }
  }

  @override
  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      final tracks = _localStream!.getVideoTracks();
      tracks.forEach((track) {
        track.enabled = enabled;
      });
    }
  }

  @override
  void toggleMute(bool muted) {
    if (_localStream != null) {
      final tracks = _localStream!.getAudioTracks();
      tracks.forEach((track) {
        track.enabled = !muted;
      });
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
      }
    }
  }

  @override
  Future<void> enableSpeakerphone(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (e) {
      print("Error setting speakerphone: $e");
    }
  }

  @override
  Future<void> dispose() async {
    await _localStream?.dispose();
    _localStream = null;
  }
}
