// FILE: lib/models.dart

// A simple model for a user profile
class Profile {
  final String id;
  final String fullName;
  final String? avatarUrl;

  Profile({required this.id, required this.fullName, this.avatarUrl});

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      fullName: map['full_name'] ?? 'No Name',
      avatarUrl: map['avatar_url'],
    );
  }
}

// Enum to represent the friendship status between two users
enum FriendshipStatus { none, sent, received, friends }

// A model to combine a user's profile with their friendship status
class UserWithStatus {
  final Profile profile;
  final FriendshipStatus status;

  UserWithStatus({required this.profile, required this.status});
}

// A model for a single chat message
class Message {
  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      content: map['content'],
      senderId: map['sender_id'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

// A model for a conversation
class Conversation {
  final String id;
  final String participantOneId;
  final String participantTwoId;

  Conversation({
    required this.id,
    required this.participantOneId,
    required this.participantTwoId,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      participantOneId: map['participant_one'],
      participantTwoId: map['participant_two'],
    );
  }
}
