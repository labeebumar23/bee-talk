class AppUser {
  final String uid;
  final String displayName;
  final String nativeLanguage; // ISO code e.g. 'ur', 'tr', 'en'
  final String avatarSeed;
  final String inviteCode; // e.g. 'BT-492X'
  final int createdAt;
  final bool isOnline;
  final int lastSeen;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.nativeLanguage,
    required this.avatarSeed,
    required this.inviteCode,
    required this.createdAt,
    this.isOnline = true,
    this.lastSeen = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'avatarSeed': avatarSeed,
      'inviteCode': inviteCode,
      'createdAt': createdAt,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
    };
  }

  factory AppUser.fromMap(Map<dynamic, dynamic> map, {String? uid}) {
    return AppUser(
      uid: (map['uid'] ?? uid ?? '').toString(),
      displayName: (map['displayName'] ?? 'Bee User').toString(),
      nativeLanguage: (map['nativeLanguage'] ?? 'en').toString(),
      avatarSeed: (map['avatarSeed'] ?? 'bee_1').toString(),
      inviteCode: (map['inviteCode'] ?? '').toString(),
      createdAt: (map['createdAt'] is int) ? map['createdAt'] : DateTime.now().millisecondsSinceEpoch,
      isOnline: map['isOnline'] == true,
      lastSeen: (map['lastSeen'] is int) ? map['lastSeen'] : 0,
    );
  }

  AppUser copyWith({
    String? uid,
    String? displayName,
    String? nativeLanguage,
    String? avatarSeed,
    String? inviteCode,
    int? createdAt,
    bool? isOnline,
    int? lastSeen,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
