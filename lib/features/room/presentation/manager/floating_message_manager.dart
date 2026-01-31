import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/room/presentation/widgets/floating_message_bubble.dart';
import 'package:flutter/material.dart';

class FloatingMessageManager {
  final List<OverlayEntry> _activeFloatingMessages = [];
  String? _lastProcessedMessageId;

  void dispose() {
    for (var entry in _activeFloatingMessages) {
      entry.remove();
    }
    _activeFloatingMessages.clear();
  }

  void showFloatingMessage(
    BuildContext context,
    ChatMessage message,
    List<String> participants,
  ) {
    // Don't show duplicate messages
    if (_lastProcessedMessageId == message.id) {
      return;
    }
    _lastProcessedMessageId = message.id;

    // Find sender's position in participants list
    final senderIndex = participants.indexOf(message.senderId);
    if (senderIndex == -1) {
      return;
    }

    // Calculate position based on participant index
    final position = _calculatePosition(context, senderIndex);
    if (position == null) return;

    // Create overlay entry
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: position.dx,
        top: position.dy,
        child: FloatingMessageBubble(
          message: message.text,
          senderName: message.senderName,
          onComplete: () {
            entry.remove();
            _activeFloatingMessages.remove(entry);
          },
        ),
      ),
    );

    _activeFloatingMessages.add(entry);
    overlay.insert(entry);
  }

  Offset? _calculatePosition(BuildContext context, int senderIndex) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;

    if (senderIndex < 4) {
      // User is on the sofa (positions 0-3)
      final sofaY = screenSize.height * 0.25;
      final spacing = 80.0;
      final startX = centerX - (spacing * 1.5);
      return Offset(startX + (senderIndex * spacing), sofaY - 80);
    } else if (senderIndex == 4) {
      // Left armchair
      final armchairY = screenSize.height * 0.5;
      return Offset(60, armchairY - 80);
    } else if (senderIndex == 5) {
      // Right armchair
      final armchairY = screenSize.height * 0.5;
      return Offset(screenSize.width - 160, armchairY - 80);
    }

    return null;
  }
}
