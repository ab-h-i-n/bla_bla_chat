import 'package:bla_bla/handlers/notification_handler.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models.dart';
import '../../widgets/user_avatar.dart';

// sendNotificationToUser(userId: userId, title: title, body: body)


class RequestsSection extends StatefulWidget {
  const RequestsSection({super.key});

  @override
  State<RequestsSection> createState() => _RequestsSectionState();
}

class _RequestsSectionState extends State<RequestsSection>
    with AutomaticKeepAliveClientMixin {

  // This prevents the widget from being disposed when switching tabs
  @override
  bool get wantKeepAlive => true;

  final _supabase = Supabase.instance.client;
  late final Stream<List<Map<String, dynamic>>> _requestsStream;
  Profile? _currentUserProfile; // To store the current user's profile

  @override
  void initState() {
    super.initState();
    _initializeStream();
    _loadCurrentUserProfile(); // Load current user's profile for notifications
  }

  void _initializeStream() {
    final currentUserId = _supabase.auth.currentUser!.id;
    _requestsStream = _supabase
        .from('friend_requests')
        .stream(primaryKey: ['id']).map((listOfMaps) {
      return listOfMaps
          .where((map) =>
              map['recipient_id'] == currentUserId && map['status'] == 'pending')
          .toList();
    });
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

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final requestId = request['id'];
    final recipientId = request['recipient_id']; // Using recipientId as requested

    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'}).eq('id', requestId);

      // --- 🚀 SEND NOTIFICATION ON ACCEPT ---
      if (recipientId != null) {
        final currentUserName = _currentUserProfile?.fullName ?? 'Someone';
        await sendNotificationToUser(
          // UPDATED: Using recipientId as the target userId
          userId: recipientId,
          title: '✅ Friend Request Accepted',
          body: '$currentUserName accepted your friend request.',
        );
      }
      // ------------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request accepted!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting request: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _declineRequest(Map<String, dynamic> request) async {
    final requestId = request['id'];
    final recipientId = request['recipient_id']; // Using recipientId as requested
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'declined'}).eq('id', requestId);

      // --- 🚀 SEND NOTIFICATION ON DECLINE ---
      if (recipientId != null) {
        final currentUserName = _currentUserProfile?.fullName ?? 'Someone';
        await sendNotificationToUser(
          // UPDATED: Using recipientId as the target userId
          userId: recipientId,
          title: '❌ Friend Request Declined',
          body: '$currentUserName declined your friend request.',
        );
      }
      // -------------------------------------

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request declined.'),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error declining request: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Call super.build(context) when using AutomaticKeepAliveClientMixin
    super.build(context);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _requestsStream,
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
                  onPressed: () {
                    setState(() {
                      _initializeStream();
                    });
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No pending friend requests',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'New friend requests will appear here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            // Force refresh by recreating the stream
            setState(() {
              _initializeStream();
            });
          },
          child: ListView.builder(
            // Add PageStorageKey to preserve scroll position
            key: const PageStorageKey('requests_list'),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return RequestListTile(
                // Add a unique key to prevent state mix-ups
                key: ValueKey(request['id']),
                request: request,
                // Pass the whole request map to the handlers
                onAccept: () => _acceptRequest(request),
                onDecline: () => _declineRequest(request),
              );
            },
          ),
        );
      },
    );
  }
}

class RequestListTile extends StatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RequestListTile({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<RequestListTile> createState() => _RequestListTileState();
}

class _RequestListTileState extends State<RequestListTile>
    with AutomaticKeepAliveClientMixin {

  // Keep individual request tiles alive to prevent re-fetching profile data
  @override
  bool get wantKeepAlive => true;

  final _supabase = Supabase.instance.client;
  Future<Profile?>? _senderProfileFuture;
  Profile? _senderProfile;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _senderProfileFuture = _getSenderProfile();
  }

  Future<Profile?> _getSenderProfile() async {
    // Return cached profile if already loaded
    if (_senderProfile != null) {
      return _senderProfile;
    }

    try {
      final senderId = widget.request['sender_id'];
      if (senderId == null) return null;

      final response =
          await _supabase.from('profiles').select().eq('id', senderId).single();

      _senderProfile = Profile.fromMap(response);
      return _senderProfile;
    } catch (e) {
      debugPrint('Error loading sender profile: $e');
      return null;
    }
  }

  void _handleAccept() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    widget.onAccept();

    // Reset processing state after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _handleDecline() {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    widget.onDecline();

    // Reset processing state after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT: Call super.build(context) when using AutomaticKeepAliveClientMixin
    super.build(context);

    return FutureBuilder<Profile?>(
      future: _senderProfileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('Loading...'),
            subtitle: const Text('Loading sender information'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.grey),
                  onPressed: null,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                  onPressed: null,
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.error, color: Colors.red),
            ),
            title: const Text('Error loading user'),
            subtitle: const Text('Could not load sender information'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.grey),
                  onPressed: null,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.grey),
                  onPressed: null,
                ),
              ],
            ),
          );
        }

        final sender = snapshot.data!;
        final requestTime = DateTime.tryParse(widget.request['created_at'] ?? '');
        final timeAgo = requestTime != null
            ? _getTimeAgo(requestTime)
            : '';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: UserAvatar(avatarUrl: sender.avatarUrl),
            title: Text(
              sender.fullName,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Wants to be your friend'),
                if (timeAgo.isNotEmpty)
                  Text(
                    timeAgo,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: _handleAccept,
                        tooltip: 'Accept',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: _handleDecline,
                        tooltip: 'Decline',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}