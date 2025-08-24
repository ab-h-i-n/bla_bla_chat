// FILE: lib/features/home/chats_section.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models.dart';
import '../../widgets/user_avatar.dart';
import '../chat/chat_page.dart';

class ChatsSection extends StatefulWidget {
  const ChatsSection({super.key});

  @override
  State<ChatsSection> createState() => _ChatsSectionState();
}

class _ChatsSectionState extends State<ChatsSection> 
    with AutomaticKeepAliveClientMixin {
  
  // This prevents the widget from being disposed when switching tabs
  @override
  bool get wantKeepAlive => true;
  
  final _supabase = Supabase.instance.client;
  final _conversationsController = StreamController<List<Map<String, dynamic>>>();
  StreamSubscription? _sub1;
  StreamSubscription? _sub2;
  List<Map<String, dynamic>> _list1 = [];
  List<Map<String, dynamic>> _list2 = [];

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    final currentUserId = _supabase.auth.currentUser!.id;

    final stream1 = _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('participant_one', currentUserId);

    final stream2 = _supabase
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('participant_two', currentUserId);

    _sub1 = stream1.listen((data) {
      _list1 = data;
      _combineAndEmit();
    });

    _sub2 = stream2.listen((data) {
      _list2 = data;
      _combineAndEmit();
    });
  }

  void _combineAndEmit() {
    final allConversations = [..._list1, ..._list2];
    final uniqueIds = <String>{};
    final uniqueConversations = <Map<String, dynamic>>[];
    for (var conversation in allConversations) {
      if (uniqueIds.add(conversation['id'])) {
        uniqueConversations.add(conversation);
      }
    }
    uniqueConversations.sort((a, b) =>
        DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
    
    _conversationsController.add(uniqueConversations);
  }

  @override
  void dispose() {
    _sub1?.cancel();
    _sub2?.cancel();
    _conversationsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Call super.build(context) when using AutomaticKeepAliveClientMixin
    super.build(context);
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _conversationsController.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final conversations = snapshot.data ?? [];
        if (conversations.isEmpty) {
          return const Center(child: Text('Start a conversation with a friend!'));
        }

        return ListView.builder(
          // Add PageStorageKey to preserve scroll position
          key: const PageStorageKey('conversations_list'),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            final conversation = conversations[index];
            return ConversationTile(
              // Add a unique key to prevent state mix-ups
              key: ValueKey(conversation['id']),
              conversation: conversation,
            );
          },
        );
      },
    );
  }
}

class ConversationTile extends StatefulWidget {
  final Map<String, dynamic> conversation;

  const ConversationTile({super.key, required this.conversation});

  @override
  State<ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<ConversationTile> 
    with AutomaticKeepAliveClientMixin {
  
  // Keep individual conversation tiles alive to prevent re-fetching profile data
  @override
  bool get wantKeepAlive => true;
  
  final _supabase = Supabase.instance.client;
  Future<Profile?>? _recipientProfileFuture;
  Profile? _recipientProfile;
  late final Stream<Message?> _lastMessageStream;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _recipientProfileFuture = _getRecipientProfile();
    // Create a stream to get the last message for this conversation
    _lastMessageStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', widget.conversation['id'])
        .order('created_at', ascending: false)
        .limit(1)
        .map((maps) => maps.isNotEmpty ? Message.fromMap(maps.first) : null);
  }

  Future<Profile?> _getRecipientProfile() async {
    // Return cached profile if already loaded
    if (_recipientProfile != null) {
      return _recipientProfile;
    }

    try {
      final currentUserId = _supabase.auth.currentUser!.id;
      final participantOne = widget.conversation['participant_one'];
      final participantTwo = widget.conversation['participant_two'];
      final recipientId =
          currentUserId == participantOne ? participantTwo : participantOne;

      final response =
          await _supabase.from('profiles').select().eq('id', recipientId).single();
      
      _recipientProfile = Profile.fromMap(response);
      return _recipientProfile;
    } catch (e) {
      debugPrint('Error loading recipient profile: $e');
      return null;
    }
  }

  void _navigateToChat() {
    if (_recipientProfile == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: widget.conversation['id'],
          recipient: _recipientProfile!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Call super.build(context) when using AutomaticKeepAliveClientMixin
    super.build(context);
    
    return FutureBuilder<Profile?>(
      future: _recipientProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('Loading...'),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const ListTile(
            leading: CircleAvatar(child: Icon(Icons.error)),
            title: Text('Error loading user'),
          );
        }

        final recipient = snapshot.data!;
        return StreamBuilder<Message?>(
          stream: _lastMessageStream,
          builder: (context, messageSnapshot) {
            // If there's no message, show an empty string.
            final lastMessage = messageSnapshot.data?.content ?? '';
            final hasNewMessage = messageSnapshot.connectionState == ConnectionState.active;
            
            return ListTile(
              leading: UserAvatar(avatarUrl: recipient.avatarUrl),
              title: Text(
                recipient.fullName,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: lastMessage.isEmpty ? Colors.grey : null,
                ),
              ),
              trailing: hasNewMessage && lastMessage.isNotEmpty
                  ? const Icon(Icons.circle, color: Colors.blue, size: 12)
                  : null,
              onTap: _navigateToChat,
            );
          },
        );
      },
    );
  }
}