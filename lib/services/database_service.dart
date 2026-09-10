import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/models/chat_room_model.dart';
import '../core/models/message_model.dart';
import '../core/models/user_model.dart';

class DatabaseService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  DatabaseReference get _usersRef => _db.ref(AppConstants.pathUsers);
  DatabaseReference get _invitesRef => _db.ref(AppConstants.pathInvites);
  DatabaseReference get _chatRoomsRef => _db.ref(AppConstants.pathChatRooms);
  DatabaseReference get _messagesRef => _db.ref(AppConstants.pathMessages);
  DatabaseReference get _userChatsRef => _db.ref(AppConstants.pathUserChats);
  DatabaseReference get _presenceRef => _db.ref(AppConstants.pathPresence);

  // ----------------------------------------------------
  // USER PROFILES & PRESENCE
  // ----------------------------------------------------

  Future<void> saveUserProfile(AppUser user) async {
    await _usersRef.child(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUserProfile(String uid) async {
    try {
      final snapshot = await _usersRef.child(uid).get();
      if (snapshot.exists && snapshot.value is Map) {
        return AppUser.fromMap(snapshot.value as Map, uid: uid);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateUserLanguage(String uid, String newLanguage) async {
    await _usersRef.child(uid).update({'nativeLanguage': newLanguage});
  }

  Future<void> updateDisplayName(String uid, String newName) async {
    await _usersRef.child(uid).update({'displayName': newName});
  }

  /// Sets up online/offline presence using Firebase onDisconnect
  void setupPresence(String uid) {
    final userPresenceRef = _presenceRef.child(uid);
    final connectedRef = _db.ref('.info/connected');

    connectedRef.onValue.listen((event) {
      final connected = event.snapshot.value == true;
      if (connected) {
        userPresenceRef.onDisconnect().update({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });

        userPresenceRef.update({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });
      }
    });
  }

  Stream<bool> getUserOnlineStatusStream(String uid) {
    return _presenceRef.child(uid).child('isOnline').onValue.map((event) {
      return event.snapshot.value == true;
    });
  }

  // ----------------------------------------------------
  // INVITE-ONLY PRIVACY & ROOM SETUP
  // ----------------------------------------------------

  /// Registers an invite code created by User A
  Future<void> registerInviteCode(String code, AppUser creator) async {
    await _invitesRef.child(code).set({
      'code': code,
      'creatorUid': creator.uid,
      'creatorName': creator.displayName,
      'creatorLang': creator.nativeLanguage,
      'creatorAvatarSeed': creator.avatarSeed,
      'createdAt': ServerValue.timestamp,
      'status': 'active',
    });
  }

  /// Validates an invite code and creates a secure 1-on-1 room between User A and User B
  Future<ChatRoom> joinChatWithInviteCode({
    required String code,
    required AppUser joiningUser,
  }) async {
    final snapshot = await _invitesRef.child(code).get();
    if (!snapshot.exists || snapshot.value == null) {
      throw Exception("Invalid invite code. Please check and try again.");
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final creatorUid = data['creatorUid'].toString();

    if (creatorUid == joiningUser.uid) {
      throw Exception("You cannot use your own invite code to chat with yourself.");
    }

    // Deterministic room ID for 1-on-1 chat
    final sortedUids = [joiningUser.uid, creatorUid]..sort();
    final roomId = 'room_${sortedUids[0]}_${sortedUids[1]}';

    // Fetch creator's latest profile
    final creatorUser = await getUserProfile(creatorUid);
    final creatorName = creatorUser?.displayName ?? data['creatorName'] ?? 'Bee User';
    final creatorLang = creatorUser?.nativeLanguage ?? data['creatorLang'] ?? 'en';
    final creatorAvatar = creatorUser?.avatarSeed ?? data['creatorAvatarSeed'] ?? 'bee_1';

    final participants = {
      joiningUser.uid: ChatParticipant(
        uid: joiningUser.uid,
        displayName: joiningUser.displayName,
        nativeLanguage: joiningUser.nativeLanguage,
        avatarSeed: joiningUser.avatarSeed,
      ),
      creatorUid: ChatParticipant(
        uid: creatorUid,
        displayName: creatorName,
        nativeLanguage: creatorLang,
        avatarSeed: creatorAvatar,
      ),
    };

    final chatRoom = ChatRoom(
      roomId: roomId,
      participantUids: sortedUids,
      participants: participants,
      lastMessageText: "Chat established 🐝",
      lastMessageSenderId: joiningUser.uid,
      lastMessageSenderLang: joiningUser.nativeLanguage,
      lastMessageTimestamp: DateTime.now().millisecondsSinceEpoch,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    // Save chat room in /chat_rooms/{roomId}
    await _chatRoomsRef.child(roomId).set(chatRoom.toMap());

    // Link chat room to both users' active chat lists in /user_chats/{uid}/{roomId}
    await _userChatsRef.child(joiningUser.uid).child(roomId).set({
      'roomId': roomId,
      'otherUid': creatorUid,
      'createdAt': ServerValue.timestamp,
    });

    await _userChatsRef.child(creatorUid).child(roomId).set({
      'roomId': roomId,
      'otherUid': joiningUser.uid,
      'createdAt': ServerValue.timestamp,
    });

    return chatRoom;
  }

  // ----------------------------------------------------
  // REAL-TIME CHAT ROOMS & MESSAGING WITH MONTHLY AUTO-CLEAR
  // ----------------------------------------------------

  /// Retention period for monthly auto-clear (30 days in milliseconds)
  static const int monthlyRetentionMs = 30 * 24 * 60 * 60 * 1000;

  /// Real-time stream of all active chat rooms for the current user
  Stream<List<ChatRoom>> getUserChatRoomsStream(String uid) {
    return _userChatsRef.child(uid).onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <ChatRoom>[];
      }

      final data = event.snapshot.value as Map;
      final roomIds = data.keys.map((k) => k.toString()).toList();
      final List<ChatRoom> rooms = [];

      for (final roomId in roomIds) {
        final roomSnap = await _chatRoomsRef.child(roomId).get();
        if (roomSnap.exists && roomSnap.value is Map) {
          final room = ChatRoom.fromMap(roomSnap.value as Map, roomId: roomId);
          rooms.add(room);
        }
      }

      // Sort by newest message first
      rooms.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      return rooms;
    });
  }

  /// Real-time stream of messages in a room with automated 30-day monthly auto-clear privacy
  Stream<List<Message>> getMessagesStream(String roomId) {
    final cutoffTimestamp = DateTime.now().millisecondsSinceEpoch - monthlyRetentionMs;

    return _messagesRef.child(roomId).orderByChild('timestamp').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <Message>[];
      }

      final data = event.snapshot.value as Map;
      final List<Message> activeMessages = [];
      final List<String> expiredMessageIds = [];

      data.forEach((key, val) {
        if (val is Map) {
          final msg = Message.fromMap(val, id: key.toString(), roomId: roomId);
          if (msg.timestamp >= cutoffTimestamp) {
            activeMessages.add(msg);
          } else {
            expiredMessageIds.add(key.toString());
          }
        }
      });

      // Asynchronously prune expired messages older than 30 days from database (Privacy)
      if (expiredMessageIds.isNotEmpty) {
        for (final expiredId in expiredMessageIds) {
          _messagesRef.child(roomId).child(expiredId).remove();
        }
      }

      activeMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return activeMessages;
    });
  }

  /// Sends a message and updates the room's last message metadata
  Future<void> sendMessage({
    required String roomId,
    required AppUser sender,
    required String text,
  }) async {
    final messageRef = _messagesRef.child(roomId).push();
    final messageId = messageRef.key!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final message = Message(
      id: messageId,
      roomId: roomId,
      senderId: sender.uid,
      senderName: sender.displayName,
      originalText: text.trim(),
      senderLanguage: sender.nativeLanguage,
      timestamp: timestamp,
    );

    // Save message
    await messageRef.set(message.toMap());

    // Update room summary
    await _chatRoomsRef.child(roomId).update({
      'lastMessageText': text.trim(),
      'lastMessageSenderId': sender.uid,
      'lastMessageSenderLang': sender.nativeLanguage,
      'lastMessageTimestamp': timestamp,
    });
  }
}
