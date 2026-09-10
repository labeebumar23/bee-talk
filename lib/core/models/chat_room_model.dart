class ChatParticipant {
  final String uid;
  final String displayName;
  final String nativeLanguage;
  final String avatarSeed;

  ChatParticipant({
    required this.uid,
    required this.displayName,
    required this.nativeLanguage,
    required this.avatarSeed,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'avatarSeed': avatarSeed,
    };
  }

  factory ChatParticipant.fromMap(Map<dynamic, dynamic> map) {
    return ChatParticipant(
      uid: (map['uid'] ?? '').toString(),
      displayName: (map['displayName'] ?? 'Friend').toString(),
      nativeLanguage: (map['nativeLanguage'] ?? 'en').toString(),
      avatarSeed: (map['avatarSeed'] ?? 'bee_2').toString(),
    );
  }
}

class ChatRoom {
  final String roomId;
  final List<String> participantUids;
  final Map<String, ChatParticipant> participants;
  final String lastMessageText;
  final String lastMessageSenderId;
  final String lastMessageSenderLang;
  final int lastMessageTimestamp;
  final int createdAt;
  final int unreadCount;

  ChatRoom({
    required this.roomId,
    required this.participantUids,
    required this.participants,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.lastMessageSenderLang,
    required this.lastMessageTimestamp,
    required this.createdAt,
    this.unreadCount = 0,
  });

  ChatParticipant? getOtherParticipant(String myUid) {
    for (final entry in participants.entries) {
      if (entry.key != myUid) {
        return entry.value;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'roomId': roomId,
      'participantUids': participantUids,
      'participants': participants.map((key, val) => MapEntry(key, val.toMap())),
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderLang': lastMessageSenderLang,
      'lastMessageTimestamp': lastMessageTimestamp,
      'createdAt': createdAt,
    };
  }

  factory ChatRoom.fromMap(Map<dynamic, dynamic> map, {String? roomId}) {
    final rawUids = map['participantUids'];
    List<String> uids = [];
    if (rawUids is List) {
      uids = rawUids.map((e) => e.toString()).toList();
    } else if (rawUids is Map) {
      uids = rawUids.values.map((e) => e.toString()).toList();
    }

    final rawParts = map['participants'];
    Map<String, ChatParticipant> parts = {};
    if (rawParts is Map) {
      rawParts.forEach((key, val) {
        if (val is Map) {
          parts[key.toString()] = ChatParticipant.fromMap(val);
        }
      });
    }

    return ChatRoom(
      roomId: (map['roomId'] ?? roomId ?? '').toString(),
      participantUids: uids,
      participants: parts,
      lastMessageText: (map['lastMessageText'] ?? '').toString(),
      lastMessageSenderId: (map['lastMessageSenderId'] ?? '').toString(),
      lastMessageSenderLang: (map['lastMessageSenderLang'] ?? 'en').toString(),
      lastMessageTimestamp: (map['lastMessageTimestamp'] is int) ? map['lastMessageTimestamp'] : 0,
      createdAt: (map['createdAt'] is int) ? map['createdAt'] : 0,
      unreadCount: (map['unreadCount'] is int) ? map['unreadCount'] : 0,
    );
  }

  ChatRoom copyWith({
    String? roomId,
    List<String>? participantUids,
    Map<String, ChatParticipant>? participants,
    String? lastMessageText,
    String? lastMessageSenderId,
    String? lastMessageSenderLang,
    int? lastMessageTimestamp,
    int? createdAt,
    int? unreadCount,
  }) {
    return ChatRoom(
      roomId: roomId ?? this.roomId,
      participantUids: participantUids ?? this.participantUids,
      participants: participants ?? this.participants,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderLang: lastMessageSenderLang ?? this.lastMessageSenderLang,
      lastMessageTimestamp: lastMessageTimestamp ?? this.lastMessageTimestamp,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
