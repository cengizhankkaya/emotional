enum PeerStatus {
  /// No connection, or it failed or closed.
  none,

  /// Offer/answer or ICE still in progress (or briefly disconnected).
  negotiating,

  /// Media is flowing.
  connected,
}
