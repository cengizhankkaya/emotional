enum BrowserMediaPermission {
  /// Camera and microphone can be used.
  granted,

  /// The browser will ask when the call starts.
  prompt,

  /// Blocked in the site settings; only the user can undo it.
  denied,

  /// No camera or microphone is connected.
  noDevice,
}
