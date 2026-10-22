import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';
import 'package:emotional/features/call/domain/enums/call_quality_preset.dart';
import 'package:emotional/features/call/domain/screen_share/screen_share_options.dart';
import 'package:emotional/features/call/domain/services/i_media_device_service.dart';
import 'package:emotional/features/call/service/screen_share/browser_screen_capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:audio_session/audio_session.dart';

class MediaDeviceService implements IMediaDeviceService {
  MediaStream? _cameraStream;
  MediaStream? _screenStream;
  CallQualityPreset _currentQuality = CallQualityPreset.balanced;

  // Keep track of selected devices to preserve selection during quality change
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;
  String? _selectedAudioOutputId;
  bool _isBusy = false;

  /// The microphone or camera stopped on its own: unplugged, a Bluetooth
  /// headset disconnected, or the OS/browser took it away. Our own stop()
  /// calls don't count.
  @override
  void Function()? onMicrophoneLost;
  @override
  void Function()? onCameraLost;

  @override
  CallQualityPreset get currentQuality => _currentQuality;

  @override
  String? get selectedVideoDeviceId => _selectedVideoDeviceId;
  @override
  String? get selectedAudioDeviceId => _selectedAudioDeviceId;
  @override
  String? get selectedAudioOutputId => _selectedAudioOutputId;

  @override
  MediaStream? get localStream => _cameraStream;

  @override
  MediaStream? get screenStream => _screenStream;

  @override
  Future<void> initialize({
    CallQualityPreset? quality,
    bool enableVideo = true,
    bool enableAudio = true,
  }) async {
    // Reopening the camera (after a screen share or a suspend) keeps the
    // quality the user picked.
    if (quality != null) _currentQuality = quality;

    try {
      await _tryStartStream(_currentQuality, requireVideo: enableVideo);
    } catch (e) {
      debugPrint(
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
    debugPrint(
      "MediaDeviceService: Attempting to start stream with quality: ${quality.name}",
    );

    // Stop and dispose previous if any
    if (_cameraStream != null) {
      await _stopStream(_cameraStream);
      _cameraStream = null;
    }

    final videoConstraints = _videoConstraints(quality);

    final audioConstraints = _audioConstraints();

    final mediaConstraints = {
      'audio': audioConstraints,
      'video': requireVideo ? videoConstraints : false,
    };

    try {
      _cameraStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      _watch(_cameraStream);
      _holdResolution(_cameraStream);
      // _currentQuality stays the user's pick even when a lower one opened,
      // so the next reopen tries the picked quality again.
      debugPrint(
        "MediaDeviceService: Stream started successfully with ${quality.name}",
      );
    } catch (e) {
      debugPrint(
        "MediaDeviceService: Failed to start with ${quality.name}. Error: $e",
      );

      // Fallback Logic
      final nextQuality = _getNextLowerQuality(quality);
      if (nextQuality != null) {
        debugPrint(
          "MediaDeviceService: Fallback -> Retrying with ${nextQuality.name}",
        );
        await _tryStartStream(nextQuality, requireVideo: requireVideo);
      } else {
        // If lowest quality video also fails, try AUDIO ONLY as last resort
        debugPrint(
          "MediaDeviceService: All video qualities failed. Trying Audio Only.",
        );
        try {
          _cameraStream = await navigator.mediaDevices.getUserMedia({
            'audio': audioConstraints,
            'video': false,
          });
          _watch(_cameraStream);
          debugPrint("MediaDeviceService: Audio-only stream started.");
        } catch (audioError) {
          debugPrint("MediaDeviceService: Audio-only also failed. Giving up.");
          rethrow;
        }
      }
    }
  }

  /// Google-tuned audio constraints, on the selected microphone if any.
  Map<String, dynamic> _audioConstraints() => {
    'echoCancellation': true,
    'noiseSuppression': true,
    'autoGainControl': true,
    'googEchoCancellation': true,
    'googEchoCancellation2': true,
    'googAutoGainControl': true,
    'googNoiseSuppression': true,
    'googHighpassFilter': true,
    'deviceId': ?_selectedAudioDeviceId,
  };

  /// Browsers lower a camera's resolution first when the connection or the
  /// computer can't keep up. 'detail' makes them drop frames instead, so
  /// the picked quality stays.
  void _holdResolution(MediaStream? stream) {
    if (!kIsWeb || stream == null) return;
    for (final track in stream.getVideoTracks()) {
      BrowserScreenCapture.applyContentHint(track, 'detail');
    }
  }

  void _watch(MediaStream? stream) {
    if (stream == null) return;
    for (final track in stream.getAudioTracks()) {
      _watchTrack(track);
    }
    for (final track in stream.getVideoTracks()) {
      _watchTrack(track);
    }
  }

  void _watchTrack(MediaStreamTrack track) {
    track.onEnded = () {
      // Only tracks still in use; replaced ones are stopped by us anyway.
      final inUse =
          _cameraStream?.getTracks().any((t) => t.id == track.id) ?? false;
      if (!inUse) return;
      debugPrint('MediaDeviceService: ${track.kind} track ended by itself.');
      if (track.kind == 'audio') {
        onMicrophoneLost?.call();
      } else {
        onCameraLost?.call();
      }
    };
  }

  /// Replaces a lost microphone with the system default one, keeping the
  /// camera. Null when no microphone can be opened.
  @override
  Future<MediaStreamTrack?> restartMicrophone() async {
    // The selected device is most likely the one that went away.
    _selectedAudioDeviceId = null;
    return _replaceMicrophone();
  }

  /// Opens the selected microphone in place of the current one, leaving
  /// the camera running. Null (and the old microphone kept) on failure.
  Future<MediaStreamTrack?> _replaceMicrophone() async {
    try {
      final microphone = await navigator.mediaDevices.getUserMedia({
        'audio': _audioConstraints(),
        'video': false,
      });
      final track = microphone.getAudioTracks().firstOrNull;
      if (track == null) return null;
      final stream = _cameraStream;
      if (stream == null) {
        _cameraStream = microphone;
      } else {
        for (final old in stream.getAudioTracks().toList()) {
          await stream.removeTrack(old);
          await old.stop();
        }
        await stream.addTrack(track);
      }
      _watchTrack(track);
      return track;
    } catch (e) {
      debugPrint('MediaDeviceService: No microphone to switch to: $e');
      return null;
    }
  }

  Map<String, dynamic> _videoConstraints(CallQualityPreset quality) {
    final constraints = kIsWeb
        ? quality.toWebConstraints()
        : quality.toConstraints();
    if (_selectedVideoDeviceId != null) {
      constraints['deviceId'] = _selectedVideoDeviceId;
    } else {
      constraints['facingMode'] = 'user';
    }
    return constraints;
  }

  /// Opens the camera and adds its track to the local stream, keeping the
  /// microphone running. Null when no camera can be opened (none connected,
  /// permission denied).
  @override
  Future<MediaStreamTrack?> startCamera() async {
    final existing = _cameraStream?.getVideoTracks().firstOrNull;
    if (existing != null) {
      existing.enabled = true;
      return existing;
    }

    final opened = await _openCamera();
    if (opened == null) return null;
    final (camera, track) = opened;
    final stream = _cameraStream;
    if (stream == null) {
      _cameraStream = camera;
    } else {
      await stream.addTrack(track);
    }
    _watchTrack(track);
    return track;
  }

  /// The selected camera at the picked quality, or the best lower one it
  /// manages; null when none opens.
  Future<(MediaStream, MediaStreamTrack)?> _openCamera() async {
    for (
      CallQualityPreset? quality = _currentQuality;
      quality != null;
      quality = _getNextLowerQuality(quality)
    ) {
      try {
        final camera = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': _videoConstraints(quality),
        });
        final track = camera.getVideoTracks().firstOrNull;
        if (track == null) return null;
        _holdResolution(camera);
        return (camera, track);
      } catch (e) {
        debugPrint(
          "MediaDeviceService: Camera failed with ${quality.name}: $e",
        );
      }
    }
    return null;
  }

  /// Opens the selected camera in place of the running one, leaving the
  /// microphone alone; the old camera stays if the new one won't open.
  Future<void> _replaceCamera() async {
    final stream = _cameraStream;
    final old = stream?.getVideoTracks().firstOrNull;
    if (stream == null || old == null) return;
    final opened = await _openCamera();
    if (opened == null) return;
    final (_, track) = opened;
    track.enabled = old.enabled;
    await stream.removeTrack(old);
    await old.stop();
    await stream.addTrack(track);
    _watchTrack(track);
  }

  /// Releases the camera (its light goes off); the microphone keeps running.
  @override
  Future<void> stopCamera() async {
    final stream = _cameraStream;
    if (stream == null) return;
    for (final track in stream.getVideoTracks().toList()) {
      await stream.removeTrack(track);
      await track.stop();
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

    debugPrint("[MediaDeviceService] Changing quality to ${preset.name}...");

    try {
      if (kIsWeb) {
        // Resize the running camera; the microphone (and a share's audio
        // mix) keep going. A camera that's off opens at the new quality.
        final camera = _cameraStream?.getVideoTracks().firstOrNull;
        if (camera == null) return;
        try {
          await camera.applyConstraints(preset.toWebConstraints());
          return;
        } catch (e) {
          debugPrint('[MediaDeviceService] Reopening the camera: $e');
          await _replaceCamera();
          return;
        }
      }

      // 1. If camera is active, re-start it
      if (_cameraStream != null) {
        final hasVideo =
            _cameraStream?.getVideoTracks().any((t) => t.enabled) ?? false;
        await _tryStartStream(preset, requireVideo: hasVideo);
      }

      // 2. If screen share is active, re-start it with new constraints.
      // On web the share profile owns screen quality, and re-opening the
      // browser picker needs a fresh user gesture, so leave it running.
      if (_screenStream != null && !kIsWeb) {
        await _startScreenShareInternal(null);
      }
    } catch (e) {
      debugPrint(
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

  /// The browser's own list; the phone-oriented refinements below (and
  /// their made-up "speaker"/"earpiece" entries) don't apply to it.
  Future<List<MediaDeviceInfo>> _browserDevices(String kind) async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final seen = <String>{};
      return [
        for (final device in devices)
          if (device.kind == kind && seen.add(device.deviceId)) device,
      ];
    } catch (e) {
      debugPrint('MediaDeviceService: Could not list $kind devices: $e');
      return [];
    }
  }

  @override
  Future<List<MediaDeviceInfo>> getAudioInputs() async {
    if (kIsWeb) return _browserDevices('audioinput');
    List<MediaDeviceInfo> devices = [];
    try {
      final allDevices = await navigator.mediaDevices.enumerateDevices();
      devices = allDevices.where((d) => d.kind == 'audioinput').toList();
    } catch (e) {
      debugPrint("Error enumerating audio inputs: $e");
    }

    final Map<String, MediaDeviceInfo> uniqueDevices = {};

    // On mobile, native labels are often generic. Use audio_session to refine.
    try {
      final session = await AudioSession.instance;
      final audioDevices = await session.getDevices();

      for (var d in audioDevices) {
        if (d.isInput) {
          String label = d.name;
          final typeStr = d.type.toString().toLowerCase();

          if (typeStr.contains('builtinmic')) {
            label = LocaleKeys.call_devices_phoneMic.tr();
          } else if (typeStr.contains('wired') || typeStr.contains('headset')) {
            label = LocaleKeys.call_devices_headsetMic.tr();
          } else if (typeStr.contains('bluetooth')) {
            label = LocaleKeys.call_devices_bluetoothMic.tr(args: [d.name]);
          }

          // Try to match with existing enumerated device if possible
          final existing = devices
              .where(
                (ed) =>
                    ed.label.toLowerCase().contains(d.name.toLowerCase()) ||
                    ed.deviceId == d.id,
              )
              .firstOrNull;

          uniqueDevices[label] = MediaDeviceInfo(
            deviceId: existing?.deviceId ?? d.id,
            label: label,
            kind: 'audioinput',
            groupId: existing?.groupId ?? 'default',
          );
        }
      }
    } catch (e) {
      debugPrint("Error refining audio inputs with audio_session: $e");
    }

    // If audio_session logic didn't populate uniqueDevices, use enumerated ones
    if (uniqueDevices.isEmpty) {
      for (var d in devices) {
        uniqueDevices[d.label] = d;
      }
    }

    return uniqueDevices.values.toList();
  }

  /// Empty on browsers that can't pick a speaker (Safari): sound then
  /// follows the system's output.
  @override
  Future<List<MediaDeviceInfo>> getAudioOutputs() async {
    if (kIsWeb) return _browserDevices('audiooutput');
    List<MediaDeviceInfo> devices = [];
    try {
      final allDevices = await navigator.mediaDevices.enumerateDevices();
      devices = allDevices.where((d) => d.kind == 'audiooutput').toList();
    } catch (e) {
      debugPrint("Error enumerating audio outputs: $e");
    }

    final Map<String, MediaDeviceInfo> uniqueDevices = {};

    try {
      final session = await AudioSession.instance;
      final audioDevices = await session.getDevices();

      for (var d in audioDevices) {
        if (d.isOutput) {
          String label = d.name;
          String deviceId = d.id;

          final typeStr = d.type.toString().toLowerCase();

          if (typeStr.contains('speaker')) {
            label = LocaleKeys.call_devices_speakerPhone.tr();
            deviceId = 'speaker';
          } else if (typeStr.contains('earpiece') ||
              typeStr.contains('receiver')) {
            label = LocaleKeys.call_devices_earpiece.tr();
            deviceId = 'earpiece';
          } else if (typeStr.contains('headset') ||
              typeStr.contains('headphones') ||
              typeStr.contains('wired')) {
            label = LocaleKeys.call_devices_headsetWired.tr();
            deviceId = 'earpiece';
          } else if (typeStr.contains('bluetooth')) {
            label = LocaleKeys.call_devices_bluetoothHeadset.tr(args: [d.name]);
            deviceId = 'earpiece';
          }

          uniqueDevices[label] = MediaDeviceInfo(
            deviceId: deviceId,
            label: label,
            kind: 'audiooutput',
            groupId: 'default',
          );
        }
      }
    } catch (e) {
      debugPrint("Error getting devices from audio_session: $e");
    }

    if (uniqueDevices.isEmpty) {
      // Final fallback if everything fails
      if (devices.isEmpty) {
        return [
          MediaDeviceInfo(
            deviceId: 'speaker',
            label: LocaleKeys.call_devices_speakerPhone.tr(),
            kind: 'audiooutput',
            groupId: 'default',
          ),
          MediaDeviceInfo(
            deviceId: 'earpiece',
            label: LocaleKeys.call_devices_earpieceHeadset.tr(),
            kind: 'audiooutput',
            groupId: 'default',
          ),
        ];
      }
      for (var d in devices) {
        uniqueDevices[d.label] = d;
      }
    }

    return uniqueDevices.values.toList();
  }

  @override
  Future<void> selectVideoInput(MediaDeviceInfo device) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      _selectedVideoDeviceId = device.deviceId;
      if (kIsWeb) {
        await _replaceCamera();
        return;
      }
      // With the camera off, only remember the choice for when it's on.
      final hasVideo =
          _cameraStream?.getVideoTracks().any((t) => t.enabled) ?? false;
      await _tryStartStream(_currentQuality, requireVideo: hasVideo);
    } finally {
      _isBusy = false;
    }
  }

  @override
  Future<void> selectAudioInput(MediaDeviceInfo device) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      _selectedAudioDeviceId = device.deviceId;
      if (kIsWeb) {
        await _replaceMicrophone();
        return;
      }
      final hasVideo =
          _cameraStream?.getVideoTracks().any((t) => t.enabled) ?? false;
      await _tryStartStream(_currentQuality, requireVideo: hasVideo);
    } finally {
      _isBusy = false;
    }
  }

  @override
  Future<void> selectAudioOutput(MediaDeviceInfo device) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      _selectedAudioOutputId = device.deviceId;
      final label = device.label.toLowerCase();
      final isSpeaker = label.contains('speaker') || label.contains('hoparlör');
      await Helper.setSpeakerphoneOn(isSpeaker);
      debugPrint(
        "MediaDeviceService: Selected Audio Output ${device.label} (Speaker=$isSpeaker)",
      );
    } catch (e) {
      debugPrint("Error selecting audio output: $e");
    } finally {
      _isBusy = false;
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
      debugPrint("Error setting speakerphone: $e");
    }
  }

  // --- Screen Share ---

  @override
  Future<void> startScreenShare({ScreenShareOptions? options}) async {
    // Callers read [screenStream] afterwards; returning quietly would let
    // them report a share that never started.
    if (_isBusy) throw StateError('Media devices are busy');
    _isBusy = true;

    try {
      await _startScreenShareInternal(options);
    } catch (e) {
      debugPrint("[MediaDeviceService] Error in startScreenShare: $e");
      rethrow;
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _startScreenShareInternal(ScreenShareOptions? options) async {
    // 1. Stop previous if any
    await _stopStream(_screenStream);
    _screenStream = null;

    final mediaConstraints = kIsWeb && options != null
        ? options.toDisplayMediaConstraints()
        : <String, dynamic>{
            'audio': false,
            'video': _currentQuality.toScreenConstraints(),
          };

    _screenStream = await navigator.mediaDevices.getDisplayMedia(
      mediaConstraints,
    );

    debugPrint(
      "MediaDeviceService: Screen share stream started with ${_currentQuality.name}.",
    );
  }

  @override
  Future<void> stopScreenShare() async {
    await _stopStream(_screenStream);
    _screenStream = null;
  }

  @override
  Future<void> dispose() async {
    await _stopStream(_cameraStream);
    await _stopStream(_screenStream);
    _cameraStream = null;
    _screenStream = null;
  }

  Future<void> _stopStream(MediaStream? stream) async {
    if (stream == null) return;
    try {
      final tracks = stream.getTracks();
      for (var track in tracks) {
        track.stop();
      }
      await stream.dispose();
    } catch (e) {
      debugPrint("[MediaDeviceService] Error stopping stream: $e");
    }
  }
}
