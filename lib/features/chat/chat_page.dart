// FILE: lib/features/chat/chat_page.dart

import 'dart:async';
import 'package:bla_bla/handlers/notification_handler.dart'; // 1. IMPORT ADDED
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models.dart';
import '../../widgets/user_avatar.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final Profile recipient;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.recipient,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _messagesController = StreamController<List<Message>>();
  final _messageInputController = TextEditingController();
  final _scrollController = ScrollController();
  StreamSubscription? _messagesSubscription;

  bool _isTyping = false;
  bool _isSending = false;
  late AnimationController _typingAnimationController;
  Profile? _currentUserProfile; // 2. ADDED TO STORE SENDER'S PROFILE

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _initializeMessagesStream();
    _loadCurrentUserProfile(); // 3. ADDED TO FETCH PROFILE ON INITIALIZATION
    _messageInputController.addListener(_onTypingChanged);
  }

  // Fetches the current user's profile to use their name in notifications
  Future<void> _loadCurrentUserProfile() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final response =
          await _supabase.from('profiles').select().eq('id', userId).single();
      if (mounted) {
        setState(() {
          _currentUserProfile = Profile.fromMap(response);
        });
      }
    } catch (e) {
      debugPrint("Error loading current user profile: $e");
    }
  }

  void _initializeMessagesStream() {
    final stream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversationId)
        .order('created_at', ascending: true);

    _messagesSubscription = stream.listen((maps) {
      var messages = maps.map((map) => Message.fromMap(map)).toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _messagesController.add(messages);

      // Auto-scroll to bottom when new messages arrive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageInputController.text.trim().isNotEmpty;
    if (isCurrentlyTyping != _isTyping) {
      setState(() {
        _isTyping = isCurrentlyTyping;
      });
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _messagesController.close();
    _messageInputController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageInputController.text.trim();
    if (content.isEmpty || _isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    // Clear input immediately for better UX
    _messageInputController.clear();

    // Add haptic feedback
    HapticFeedback.lightImpact();

    try {
      await _supabase.from('messages').insert({
        'content': content,
        'sender_id': _supabase.auth.currentUser!.id,
        'conversation_id': widget.conversationId,
      });

      // --- 🚀 SEND NOTIFICATION ON NEW MESSAGE ---
      final senderName = _currentUserProfile?.fullName ?? 'New Message';
      await sendNotificationToUser(
        userId: widget.recipient.id,
        title: senderName,
        body: content,
      );
      // ------------------------------------------

    } catch (e) {
      // Restore message if failed
      _messageInputController.text = content;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to send message: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _sendMessage,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            UserAvatar(avatarUrl: widget.recipient.avatarUrl, radius: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.recipient.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Online', // You can make this dynamic later
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              // TODO: Implement video call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video call coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined),
            onPressed: () {
              // TODO: Implement voice call
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice call coming soon!')),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  // TODO: Implement clear chat
                  break;
                case 'block':
                  // TODO: Implement block user
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, size: 20, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Block User', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _messagesController.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: () {
                            setState(() {
                              _initializeMessagesStream();
                            });
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];
                final currentUserId = _supabase.auth.currentUser!.id;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        UserAvatar(
                          avatarUrl: widget.recipient.avatarUrl,
                          radius: 32,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Start a conversation with\n${widget.recipient.fullName}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '👋 Say hello!',
                          style: TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == currentUserId;
                    final showAvatar =
                        index == messages.length - 1 ||
                        messages[index + 1].senderId != message.senderId;
                    final showTime =
                        index == 0 ||
                        messages[index - 1].createdAt
                                .difference(message.createdAt)
                                .inMinutes >
                            5;

                    return ChatBubble(
                      message: message,
                      isMine: isMine,
                      showAvatar: showAvatar && !isMine,
                      showTime: showTime,
                      recipient: widget.recipient,
                      formatTime: _formatMessageTime,
                    );
                  },
                );
              },
            ),
          ),
          _MessageBar(
            controller: _messageInputController,
            onSend: _sendMessage,
            isSending: _isSending,
            isTyping: _isTyping,
          ),
        ],
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final Message message;
  final bool isMine;
  final bool showAvatar;
  final bool showTime;
  final Profile recipient;
  final String Function(DateTime) formatTime;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.showAvatar,
    required this.showTime,
    required this.recipient,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: isMine ? 50 : 16,
        right: isMine ? 16 : 50,
        top: showTime ? 16 : 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (showTime)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatTime(message.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isMine && showAvatar)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: UserAvatar(avatarUrl: recipient.avatarUrl, radius: 14),
                )
              else if (!isMine)
                const SizedBox(width: 36),
              Flexible(
                child: GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _showMessageOptions(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isMine ? Colors.white : Colors.grey[800],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMine ? 20 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message.content,
                      style: TextStyle(
                        color: isMine ? Colors.black : Colors.white,
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.white),
              title: const Text('Copy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard')),
                );
              },
            ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Implement delete message
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final bool isTyping;

  const _MessageBar({
    required this.controller,
    required this.onSend,
    required this.isSending,
    required this.isTyping,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 5,
                          minLines: 1,
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file, color: Colors.grey),
                        onPressed: () {
                          // TODO: Implement file attachment
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('File attachment coming soon!'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: isTyping ? Colors.white : Colors.grey[700],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IconButton(
                  icon: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.black,
                            ),
                          ),
                        )
                      : Icon(
                          isTyping ? Icons.send : Icons.mic,
                          color: isTyping ? Colors.black : Colors.white,
                        ),
                  onPressed: isSending
                      ? null
                      : isTyping
                      ? onSend
                      : () {
                          // TODO: Implement voice message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Voice messages coming soon!'),
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}