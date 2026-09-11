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
      lastMessageStatus: 'sent',
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
  // OPTIMIZED REAL-TIME CHAT ROOMS & PARALLEL INBOX FETCHING
  // ----------------------------------------------------

  /// Retention period for monthly auto-clear (30 days in milliseconds)
  static const int monthlyRetentionMs = 30 * 24 * 60 * 60 * 1000;

  /// Parallel-optimized real-time stream of all active chat rooms for current user
  Stream<List<ChatRoom>> getUserChatRoomsStream(String uid) {
    return _userChatsRef.child(uid).onValue.asyncMap((event) async {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        return <ChatRoom>[];
      }

      final data = event.snapshot.value as Map;
      final roomIds = data.keys.map((k) => k.toString()).toList();

      // Parallel fetch to eliminate sequential N+1 network waterfall delay
      final snapshots = await Future.wait(
        roomIds.map((roomId) => _chatRoomsRef.child(roomId).get()),
      );

      final List<ChatRoom> rooms = [];
      for (int i = 0; i < snapshots.length; i++) {
        final snap = snapshots[i];
        if (snap.exists && snap.value is Map) {
          final room = ChatRoom.fromMap(snap.value as Map, roomId: roomIds[i]);
          rooms.add(room);
        }
      }

      // Sort by newest message timestamp first
      rooms.sort((a, b) => b.lastMessageTimestamp.compareTo(a.lastMessageTimestamp));
      return rooms;
    });
  }

  // ----------------------------------------------------
  // PAGINATED MESSAGES & REAL-TIME READ RECEIPTS
  // ----------------------------------------------------

  /// Stream paginated recent messages (default last 25) with auto 30-day retention pruning
  Stream<List<Message>> getMessagesStream(String roomId, {int limit = 30}) {
    final cutoffTimestamp = DateTime.now().millisecondsSinceEpoch - monthlyRetentionMs;

    return _messagesRef
        .child(roomId)
        .orderByChild('timestamp')
        .limitToLast(limit)
        .onValue
        .map((event) {
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

      // Asynchronously prune expired messages older than 30 days
      if (expiredMessageIds.isNotEmpty) {
        for (final expiredId in expiredMessageIds) {
          _messagesRef.child(roomId).child(expiredId).remove();
        }
      }

      activeMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return activeMessages;
    });
  }

  /// Load older historical messages before a specific timestamp for pagination
  Future<List<Message>> loadEarlierMessages({
    required String roomId,
    required int endAtTimestamp,
    int limit = 25,
  }) async {
    final cutoffTimestamp = DateTime.now().millisecondsSinceEpoch - monthlyRetentionMs;

    try {
      final snap = await _messagesRef
          .child(roomId)
          .orderByChild('timestamp')
          .endBefore(endAtTimestamp)
          .limitToLast(limit)
          .get();

      if (!snap.exists || snap.value == null || snap.value is! Map) {
        return [];
      }

      final data = snap.value as Map;
      final List<Message> earlierMessages = [];

      data.forEach((key, val) {
        if (val is Map) {
          final msg = Message.fromMap(val, id: key.toString(), roomId: roomId);
          if (msg.timestamp >= cutoffTimestamp) {
            earlierMessages.add(msg);
          }
        }
      });

      earlierMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return earlierMessages;
    } catch (e) {
      debugPrint('Error loading earlier messages: $e');
      return [];
    }
  }

  /// Sends a message and updates the room's last message metadata with 'sent' status
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
      status: 'sent',
    );

    // Save message with 'sent' status
    await messageRef.set(message.toMap());

    // Update room summary
    await _chatRoomsRef.child(roomId).update({
      'lastMessageText': text.trim(),
      'lastMessageSenderId': sender.uid,
      'lastMessageSenderLang': sender.nativeLanguage,
      'lastMessageTimestamp': timestamp,
      'lastMessageStatus': 'sent',
    });
  }

  /// Mark unread incoming messages as 'seen' (WhatsApp double blue tick equivalent)
  Future<void> markMessagesAsSeen({
    required String roomId,
    required String currentUserId,
  }) async {
    try {
      final snap = await _messagesRef
          .child(roomId)
          .orderByChild('timestamp')
          .limitToLast(30)
          .get();

      if (!snap.exists || snap.value == null || snap.value is! Map) return;

      final data = snap.value as Map;
      final Map<String, Object?> updates = {};
      final seenTime = DateTime.now().millisecondsSinceEpoch;

      data.forEach((key, val) {
        if (val is Map) {
          final senderId = (val['senderId'] ?? '').toString();
          final status = (val['status'] ?? 'sent').toString();

          // If message is from the other person and not yet seen
          if (senderId.isNotEmpty && senderId != currentUserId && status != 'seen') {
            updates['$key/status'] = 'seen';
            updates['$key/seenAt'] = seenTime;
          }
        }
      });

      if (updates.isNotEmpty) {
        await _messagesRef.child(roomId).update(updates);
      }
    } catch (e) {
      debugPrint('Error marking messages as seen: $e');
    }
  }

  /// Mark incoming messages as 'delivered'
  Future<void> markMessagesAsDelivered({
    required String roomId,
    required String currentUserId,
  }) async {
    try {
      final snap = await _messagesRef
          .child(roomId)
          .orderByChild('timestamp')
          .limitToLast(20)
          .get();

      if (!snap.exists || snap.value == null || snap.value is! Map) return;

      final data = snap.value as Map;
      final Map<String, Object?> updates = {};

      data.forEach((key, val) {
        if (val is Map) {
          final senderId = (val['senderId'] ?? '').toString();
          final status = (val['status'] ?? 'sent').toString();

          if (senderId.isNotEmpty && senderId != currentUserId && status == 'sent') {
            updates['$key/status'] = 'delivered';
          }
        }
      });

      if (updates.isNotEmpty) {
        await _messagesRef.child(roomId).update(updates);
      }
    } catch (e) {
      debugPrint('Error marking messages as delivered: $e');
    }
  }
}
