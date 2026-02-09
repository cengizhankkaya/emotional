import 'dart:async';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/services/i_media_device_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class MediaDeviceService implements IMediaDeviceService {
  MediaStream? _cameraStream;
  MediaStream? _screenStream;
  CallQualityPreset _currentQuality = CallQualityPreset.balanced;

  // Keep track of selected devices to preserve selection during quality change
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;
  bool _isBusy = false;

  @override
  MediaStream? get localStream => _cameraStream;

  @override
  MediaStream? get screenStream => _screenStream;

  @override
  Future<void> initialize({
    CallQualityPreset quality = CallQualityPreset.balanced,
    bool enableVideo = true,
    bool enableAudio = true,
  }) async {
    _currentQuality = quality;

    try {
      await _tryStartStream(quality, requireVideo: enableVideo);
    } catch (e) {
      print(
        "CRITICAL: Failed to initialize media stream even after fallback: $e",
      );
    }

    // Default states
    toggleVideo(enableVideo);
    toggleMute(!enableAudio);
  }

  /// Attempts to start the stream with the requested quality.
  /// If it fails due to OverconstrainedError or similar, it recursively tries lower qualities.
  Future<void> _tryStartStream(
    CallQualityPreset quality, {
    bool requireVideo = true,
  }) async {
    print(
      "MediaDeviceService: Attempting to start stream with quality: ${quality.name}",
    );

    // Dispose previous if any
    if (_cameraStream != null) {
      await _cameraStream!.dispose();
      _cameraStream = null;
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
      'video': requireVideo ? videoConstraints : false,
    };

    try {
      _cameraStream = await navigator.mediaDevices.getUserMedia(
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
        await _tryStartStream(nextQuality, requireVideo: requireVideo);
      } else {
        // If lowest quality video also fails, try AUDIO ONLY as last resort
        print(
          "MediaDeviceService: All video qualities failed. Trying Audio Only.",
        );
        try {
          _cameraStream = await navigator.mediaDevices.getUserMedia({
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
    if (_currentQuality == preset || _isBusy) return;
    _isBusy = true;
    final oldQuality = _currentQuality;
    _currentQuality = preset;

    print("[MediaDeviceService] Changing quality to ${preset.name}...");

    try {
      // 1. If camera is active, re-start it
      if (_cameraStream != null) {
        final hasVideo =
            _cameraStream?.getVideoTracks().any((t) => t.enabled) ?? true;
        await _tryStartStream(preset, requireVideo: hasVideo);
      }

      // 2. If screen share is active, re-start it with new constraints
      if (_screenStream != null) {
        await startScreenShare();
      }
    } catch (e) {
      print(
        "[MediaDeviceService] Failed to set quality: $e. Reverting to ${oldQuality.name}",
      );
      _currentQuality = oldQuality;
      rethrow;
    } finally {
      _isBusy = false;
    }
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
    await _tryStartStream(_currentQuality, requireVideo: true);
  }

  @override
  Future<void> selectAudioInput(MediaDeviceInfo device) async {
    _selectedAudioDeviceId = device.deviceId;
    final hasVideo =
        _cameraStream?.getVideoTracks().any((t) => t.enabled) ?? true;
    await _tryStartStream(_currentQuality, requireVideo: hasVideo);
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
    if (_cameraStream != null) {
      final tracks = _cameraStream!.getVideoTracks();
      for (var track in tracks) {
        track.enabled = enabled;
      }
    }
  }

  @override
  void toggleMute(bool muted) {
    if (_cameraStream != null) {
      final tracks = _cameraStream!.getAudioTracks();
      for (var track in tracks) {
        track.enabled = !muted;
      }
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_cameraStream != null) {
      final videoTracks = _cameraStream!.getVideoTracks();
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

  // --- Screen Share ---

  @override
  Future<void> startScreenShare() async {
    if (_isBusy && _screenStream == null) return;
    final externalCall = !_isBusy;
    if (externalCall) _isBusy = true;

    try {
      if (_screenStream != null) {
        final tracks = _screenStream!.getTracks();
        for (var track in tracks) {
          track.stop();
        }
        await _screenStream!.dispose();
        _screenStream = null;
      }

      final mediaConstraints = <String, dynamic>{
        'audio': false,
        'video': _currentQuality.toScreenConstraints(),
      };

      _screenStream = await navigator.mediaDevices.getDisplayMedia(
        mediaConstraints,
      );

      print(
        "MediaDeviceService: Screen share stream started with ${_currentQuality.name}.",
      );
    } catch (e) {
      print("Error starting screen share: $e");
      rethrow;
    } finally {
      if (externalCall) _isBusy = false;
    }
  }

  @override
  Future<void> stopScreenShare() async {
    if (_screenStream != null) {
      final tracks = _screenStream!.getTracks();
      for (var track in tracks) {
        track.stop();
      }
      await _screenStream!.dispose();
      _screenStream = null;
    }
  }

  @override
  Future<void> dispose() async {
    await _cameraStream?.dispose();
    await _screenStream?.dispose();
    _cameraStream = null;
    _screenStream = null;
  }
}
