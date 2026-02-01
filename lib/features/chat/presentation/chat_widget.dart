import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

// ... (existing imports)
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class ChatWidget extends StatefulWidget {
  final String roomId;
  final VoidCallback? onClose;

  const ChatWidget({super.key, required this.roomId, this.onClose});

  @override
  State<ChatWidget> createState() => _ChatWidgetState();
}

class _ChatWidgetState extends State<ChatWidget> {
  // ... (existing state methods: initState, dispose, _scrollToBottom, _sendMessage, _formatTimestamp)

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadMessages(widget.roomId));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<ChatBloc>().add(
        SendMessage(
          roomId: widget.roomId,
          text: text,
          userId: authState.user.uid,
          userName: authState.user.displayName ?? 'Anonymous',
        ),
      );
      _textController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const ProjectPadding.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sohbet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.dynamicValue(16),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: context.dynamicValue(20),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          // Messages List
          Expanded(
            child: BlocConsumer<ChatBloc, ChatState>(
              listener: (context, state) {
                if (state is ChatLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                }
              },
              builder: (context, state) {
                if (state is ChatLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is ChatLoaded) {
                  final messages = state.messages;
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'Henüz mesaj yok',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const ProjectPadding.allMedium(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return _buildMessageItem(msg);
                    },
                  );
                } else if (state is ChatError) {
                  return Center(
                    child: Text(
                      'Hata: ${state.message}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          // Input Area
          Padding(
            padding: const ProjectPadding.allMedium(),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Mesaj yaz...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: ProjectRadius.large(),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const ProjectPadding.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: context.dynamicWidth(0.02)),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final authState = context.read<AuthBloc>().state;
    final isMe =
        authState is AuthAuthenticated && authState.user.uid == msg.senderId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 2),
              child: Text(
                msg.senderName,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: context.dynamicValue(10),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Container(
            padding: const ProjectPadding.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isMe ? Colors.blueAccent : Colors.grey[800],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(context.dynamicValue(12)),
                topRight: Radius.circular(context.dynamicValue(12)),
                bottomLeft: isMe
                    ? Radius.circular(context.dynamicValue(12))
                    : Radius.circular(context.dynamicValue(2)),
                bottomRight: isMe
                    ? Radius.circular(context.dynamicValue(2))
                    : Radius.circular(context.dynamicValue(12)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  msg.text,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.dynamicValue(14),
                  ),
                ),
                SizedBox(height: context.dynamicHeight(0.005)),
                Text(
                  _formatTimestamp(msg.timestamp),
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.white54,
                    fontSize: context.dynamicValue(9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
