import 'package:emotional/product/utility/constants/project_padding.dart';
import 'package:emotional/product/utility/constants/project_radius.dart';
import 'package:emotional/product/utility/responsiveness/responsive_extension.dart';

// ... (existing imports)
import 'package:emotional/features/auth/bloc/auth_bloc.dart';
import 'package:emotional/features/chat/bloc/chat_bloc.dart';
import 'package:emotional/features/chat/data/message_model.dart';
import 'package:emotional/features/moderation/bloc/moderation_bloc.dart';
import 'package:emotional/features/moderation/presentation/block_confirm_dialog.dart';
import 'package:emotional/features/moderation/presentation/report_dialog.dart';
import 'package:emotional/product/utility/decorations/colors_custom.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:emotional/product/init/language/locale_keys.g.dart';

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
  bool _isAtBottom = true;
  bool _hasNewMessages = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    context.read<ChatBloc>().add(LoadMessages(widget.roomId));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
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

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Kullanıcı alta yakınsa (ör. son 50 px içinde) "en alttayız" kabul et.
    final bool isNowAtBottom = position.maxScrollExtent - position.pixels <= 50;
    if (isNowAtBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = isNowAtBottom;
        if (_isAtBottom) {
          // Alta indiğinde yeni mesaj uyarısını temizle.
          _hasNewMessages = false;
        }
      });
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
          userName: authState.user.displayName ?? LocaleKeys.room_someone.tr(),
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

  /// Shows a context menu when the user long-presses a chat message.
  void _showMessageContextMenu(
    BuildContext context,
    ChatMessage msg,
    bool isMe,
  ) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsCustom.darkABlue,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            // Copy
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white70),
              title: Text(
                LocaleKeys.chat_copyMessage.tr(),
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied')),
                );
              },
            ),
            // Don't show report/block for own messages
            if (!isMe) ...[
              const Divider(color: Colors.white12),
              // Report Message
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: Text(
                  LocaleKeys.chat_reportMessage.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDialog(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: context.read<ModerationBloc>(),
                      child: ReportDialog(
                        reporterUserId: authState.user.uid,
                        reportedUserId: msg.senderId,
                        reportedUserName: msg.senderName,
                        roomId: widget.roomId,
                        messageId: msg.id,
                        messageText: msg.text,
                      ),
                    ),
                  );
                },
              ),
              // Block User
              ListTile(
                leading: const Icon(Icons.block, color: Colors.redAccent),
                title: Text(
                  LocaleKeys.chat_blockUser.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showDialog(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: context.read<ModerationBloc>(),
                      child: BlockConfirmDialog(
                        currentUserId: authState.user.uid,
                        blockedUserId: msg.senderId,
                        blockedUserName: msg.senderName,
                        roomId: widget.roomId,
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: SafeArea(
        bottom: true,
        top: false,
        child: AnimatedPadding(
          // Klavye açıldığında widget'ı yukarı iterek giriş alanının görünür kalmasını sağlar.
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
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
                      LocaleKeys.chat_title.tr(),
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
                        if (_isAtBottom) {
                          // WhatsApp davranışı: zaten alttaysak otomatik kaydır.
                          _scrollToBottom();
                        } else {
                          // Kullanıcı yukarıdaysa sadece "yeni mesaj" göstergesi aç.
                          setState(() {
                            _hasNewMessages = true;
                          });
                        }
                      });
                    }
                  },
                  builder: (context, state) {
                    if (state is ChatLoading) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (state is ChatLoaded) {
                      // Filter out blocked users' messages
                      final moderationState =
                          context.watch<ModerationBloc>().state;
                      final blockedIds = moderationState is BlockedUsersLoaded
                          ? moderationState.blockedUserIds
                          : <String>[];

                      final messages = state.messages
                          .where((m) => !blockedIds.contains(m.senderId))
                          .toList();

                      if (messages.isEmpty) {
                        return Center(
                          child: Text(
                            LocaleKeys.chat_noMessages.tr(),
                            style: const TextStyle(color: Colors.white54),
                          ),
                        );
                      }
                      return Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const ProjectPadding.allMedium(),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              return _buildMessageItem(msg);
                            },
                          ),
                          if (_hasNewMessages && !_isAtBottom)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: GestureDetector(
                                onTap: _scrollToBottom,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        LocaleKeys.chat_newMessages.tr(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    } else if (state is ChatError) {
                      return Center(
                        child: Text(
                          LocaleKeys.chat_errorPrefix.tr(args: [state.message]),
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
                          hintText: LocaleKeys.chat_typeMessage.tr(),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg) {
    final authState = context.read<AuthBloc>().state;
    final isMe =
        authState is AuthAuthenticated && authState.user.uid == msg.senderId;

    return GestureDetector(
      onLongPress: () => _showMessageContextMenu(context, msg, isMe),
      child: Padding(
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
      ),
    );
  }
}
