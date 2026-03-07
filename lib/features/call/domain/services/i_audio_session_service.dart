abstract class IAudioSessionService {
  /// Initializes and activates the audio session for a call.
  Future<void> activate();

  /// Deactivates the session, returning control to other apps (music etc.)
  Future<void> deactivate();
}
