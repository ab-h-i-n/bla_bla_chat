// FILE: lib/features/home/users_section.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models.dart';
import '../../widgets/user_avatar.dart';
import '../chat/chat_page.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> 
    with AutomaticKeepAliveClientMixin {
  
  // This prevents the widget from being disposed when switching tabs
  @override
  bool get wantKeepAlive => true;
  
  final _supabase = Supabase.instance.client;
  late Future<List<UserWithStatus>> _usersFuture;
  List<UserWithStatus>? _cachedUsers;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsersWithStatus();
  }

  Future<List<UserWithStatus>> _fetchUsersWithStatus({bool useCache = true}) async {
    // Return cached data if available and cache is allowed
    if (useCache && _cachedUsers != null && !_isRefreshing) {
      return _cachedUsers!;
    }

    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      // Fetch all profiles except current user
      final profilesResponse =
          await _supabase.from('profiles').select().neq('id', currentUserId);
      final profiles =
          (profilesResponse as List).map((e) => Profile.fromMap(e)).toList();

      // Fetch all friend requests involving current user
      final requestsResponse = await _supabase
          .from('friend_requests')
          .select()
          .or('sender_id.eq.$currentUserId,recipient_id.eq.$currentUserId');
      final requests = requestsResponse as List;

      // Build friendship status map
      final friendshipStatusMap = <String, FriendshipStatus>{};
      for (var request in requests) {
        final senderId = request['sender_id'];
        final recipientId = request['recipient_id'];
        final status = request['status'];
        final otherUserId = senderId == currentUserId ? recipientId : senderId;

        if (status == 'accepted') {
          friendshipStatusMap[otherUserId] = FriendshipStatus.friends;
        } else if (status == 'pending') {
          if (senderId == currentUserId) {
            friendshipStatusMap[otherUserId] = FriendshipStatus.sent;
          } else {
            friendshipStatusMap[otherUserId] = FriendshipStatus.received;
          }
        }
      }

      // Combine profiles with their friendship status
      final usersWithStatus = profiles.map((profile) {
        final status = friendshipStatusMap[profile.id] ?? FriendshipStatus.none;
        return UserWithStatus(profile: profile, status: status);
      }).toList();

      // Sort users: friends first, then by name
      usersWithStatus.sort((a, b) {
        if (a.status == FriendshipStatus.friends && b.status != FriendshipStatus.friends) {
          return -1;
        } else if (a.status != FriendshipStatus.friends && b.status == FriendshipStatus.friends) {
          return 1;
        }
        return a.profile.fullName.compareTo(b.profile.fullName);
      });

      // Cache the results
      _cachedUsers = usersWithStatus;
      return usersWithStatus;
    } catch (e) {
      debugPrint('Error fetching users with status: $e');
      rethrow;
    }
  }

  Future<void> _refreshUsers() async {
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      _cachedUsers = null; // Clear cache
      final users = await _fetchUsersWithStatus(useCache: false);
      setState(() {
        _usersFuture = Future.value(users);
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String recipientId) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    try {
      await _supabase.from('friend_requests').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Refresh the data to show updated status
      await _refreshUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _startChat(BuildContext context, Profile friendProfile) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      // Find existing conversation or create new one
      final response = await _supabase
          .from('conversations')
          .select('id')
          .or(
            'and(participant_one.eq.$currentUserId,participant_two.eq.${friendProfile.id}),'
            'and(participant_one.eq.${friendProfile.id},participant_two.eq.$currentUserId)',
          )
          .maybeSingle();

      String conversationId;
      if (response != null && response['id'] != null) {
        // Conversation already exists
        conversationId = response['id'];
      } else {
        // Create a new conversation
        final newConversation = await _supabase.from('conversations').insert({
          'participant_one': currentUserId,
          'participant_two': friendProfile.id,
        }).select('id').single();
        conversationId = newConversation['id'];
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        // Navigate to the chat page
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: conversationId,
              recipient: friendProfile,
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting chat: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildTrailingWidget(UserWithStatus userWithStatus) {
    switch (userWithStatus.status) {
      case FriendshipStatus.none:
        return IconButton(
          icon: const Icon(Icons.person_add_alt_1, color: Colors.blue),
          onPressed: () => _sendFriendRequest(userWithStatus.profile.id),
          tooltip: 'Send Friend Request',
        );
      case FriendshipStatus.sent:
        return const Tooltip(
          message: 'Friend request sent',
          child: Chip(
            label: Text(
              'Sent',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            backgroundColor: Colors.grey,
          ),
        );
      case FriendshipStatus.received:
        return const Tooltip(
          message: 'Check requests tab',
          child: Chip(
            label: Text(
              'Pending',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      case FriendshipStatus.friends:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chat, color: Colors.blue),
              onPressed: () => _startChat(context, userWithStatus.profile),
              tooltip: 'Start Chat',
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Call super.build(context) when using AutomaticKeepAliveClientMixin
    super.build(context);
    
    return FutureBuilder<List<UserWithStatus>>(
      future: _usersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshUsers,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshUsers,
            child: ListView(
              children: const [
                SizedBox(height: 200),
                Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pull down to refresh',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Group users by status for better organization
        final friends = users.where((u) => u.status == FriendshipStatus.friends).toList();
        final others = users.where((u) => u.status != FriendshipStatus.friends).toList();

        return RefreshIndicator(
          onRefresh: _refreshUsers,
          child: ListView(
            // Add PageStorageKey to preserve scroll position
            key: const PageStorageKey('users_list'),
            children: [
              if (friends.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                ...friends.map((userWithStatus) => UserListTile(
                  key: ValueKey('friend_${userWithStatus.profile.id}'),
                  userWithStatus: userWithStatus,
                  trailingWidget: _buildTrailingWidget(userWithStatus),
                )),
                const Divider(),
              ],
              if (others.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Other Users',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ...others.map((userWithStatus) => UserListTile(
                  key: ValueKey('user_${userWithStatus.profile.id}'),
                  userWithStatus: userWithStatus,
                  trailingWidget: _buildTrailingWidget(userWithStatus),
                )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class UserListTile extends StatelessWidget {
  final UserWithStatus userWithStatus;
  final Widget trailingWidget;

  const UserListTile({
    super.key,
    required this.userWithStatus,
    required this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final user = userWithStatus.profile;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      elevation: 1,
      child: ListTile(
        leading: UserAvatar(avatarUrl: user.avatarUrl),
        title: Text(
          user.fullName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          _getStatusText(userWithStatus.status),
          style: TextStyle(
            color: _getStatusColor(userWithStatus.status),
            fontSize: 12,
          ),
        ),
        trailing: trailingWidget,
      ),
    );
  }

  String _getStatusText(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.friends:
        return 'Friend';
      case FriendshipStatus.sent:
        return 'Request sent';
      case FriendshipStatus.received:
        return 'Request received';
      case FriendshipStatus.none:
        return 'Not connected';
    }
  }

  Color _getStatusColor(FriendshipStatus status) {
    switch (status) {
      case FriendshipStatus.friends:
        return Colors.green;
      case FriendshipStatus.sent:
        return Colors.grey;
      case FriendshipStatus.received:
        return Colors.orange;
      case FriendshipStatus.none:
        return Colors.grey;
    }
  }
}