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

    await _startStream();
    // Varsayılan olarak açık başlıyoruz, sorunları ekarte etmek için
    toggleVideo(true);
    toggleMute(false);
  }

  Future<void> _startStream() async {
    // Dipose previous stream if exists (except potentially keeping tracks if we were doing seamless switch,
    // but for simplicity we restart for constraints changes)
    if (_localStream != null) {
      await _localStream!.dispose();
      _localStream = null;
    }

    final videoConstraints = _currentQuality.toConstraints();

    // If a specific device is selected, add it to constraints
    if (_selectedVideoDeviceId != null) {
      videoConstraints['deviceId'] = _selectedVideoDeviceId;
    } else {
      videoConstraints['facingMode'] = 'user'; // Default to front camera
    }

    final audioConstraints = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
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
    } catch (e) {
      // Fallback: try audio only if video fails, or default constraints if specific fails
      // For now, rethrow or handle specific errors like 'PermissionDeniedError'
      print("Error getting user media: $e");
      rethrow;
    }
  }

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
    await _startStream();
  }

  @override
  Future<void> selectAudioInput(MediaDeviceInfo device) async {
    _selectedAudioDeviceId = device.deviceId;
    await _startStream();
  }

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    // Note: setSinkId is not supported on all platforms/browsers (mainly Chrome desktop)
    // On Mobile (Flutter WebRTC), this might need specific audio switching logic if not handled by OS
    try {
      // Helper.selectAudioOutput(device.deviceId); // This is specific to web usually
      // For mobile, we usually rely on OS routing or specific plugins like audio_session
      print("Mock: Selecting Audio Output ${device.label}");
    } catch (e) {
      print("Error selecting audio output: $e");
    }
  }

  @override
  void toggleVideo(bool enabled) {
    if (_localStream != null) {
      final tracks = _localStream!.getVideoTracks();
      print(
        'MediaDeviceService: Toggling video to $enabled. Found ${tracks.length} video tracks.',
      );
      tracks.forEach((track) {
        track.enabled = enabled;
        print(
          'MediaDeviceService: Video track ${track.id} enabled set to $enabled',
        );
      });
    } else {
      print('MediaDeviceService: _localStream is null, cannot toggle video.');
    }
  }

  @override
  void toggleMute(bool muted) {
    if (_localStream != null) {
      final tracks = _localStream!.getAudioTracks();
      print(
        'MediaDeviceService: Toggling mute to $muted. Found ${tracks.length} audio tracks.',
      );
      tracks.forEach((track) {
        track.enabled = !muted;
        print(
          'MediaDeviceService: Audio track ${track.id} enabled set to ${!muted}',
        );
      });
    } else {
      print('MediaDeviceService: _localStream is null, cannot toggle mute.');
    }
  }

  @override
  Future<void> setQuality(CallQualityPreset preset) async {
    if (_currentQuality == preset) return;
    _currentQuality = preset;
    // We need to restart the stream to apply new resolution constraints usually
    // Some implementations allow applyConstraints() on track, but restarting is safer for broad support
    await _startStream();
  }

  @override
  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks.first);
        // Note: Helper.switchCamera internal implementation typically rotates through available cameras.
        // It might overwrite our _selectedVideoDeviceId logic if we rely on that.
        // For a mixed approach, simple switchCamera is fine for mobile.
      }
    }
  }

  @override
  Future<void> enableSpeakerphone(bool enabled) async {
    // This helper is specifically for mobile (Android/iOS) to route audio
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
