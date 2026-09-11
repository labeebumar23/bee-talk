class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String originalText;
  final String senderLanguage; // e.g. 'ur', 'tr', 'en'
  final int timestamp;
  final String status; // 'sent', 'delivered', 'seen'
  final int? seenAt;
  
  // Local/On-device state fields (not stored in Realtime DB)
  String? translatedText;
  bool isTranslating;
  bool translationFailed;
  bool showOriginal; // Toggled by the 👁️ eye icon

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.originalText,
    required this.senderLanguage,
    required this.timestamp,
    this.status = 'sent',
    this.seenAt,
    this.translatedText,
    this.isTranslating = false,
    this.translationFailed = false,
    this.showOriginal = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'originalText': originalText,
      'text': originalText,
      'senderLanguage': senderLanguage,
      'senderLang': senderLanguage,
      'timestamp': timestamp,
      'status': status,
      if (seenAt != null) 'seenAt': seenAt,
    };
  }

  factory Message.fromMap(Map<dynamic, dynamic> map, {String? id, String? roomId}) {
    final textVal = (map['text'] ?? map['originalText'] ?? '').toString();
    final langVal = (map['senderLang'] ?? map['senderLanguage'] ?? 'en').toString();
    
    return Message(
      id: (map['id'] ?? id ?? '').toString(),
      roomId: (map['roomId'] ?? roomId ?? '').toString(),
      senderId: (map['senderId'] ?? '').toString(),
      senderName: (map['senderName'] ?? '').toString(),
      originalText: textVal,
      senderLanguage: langVal,
      timestamp: (map['timestamp'] is int) ? map['timestamp'] as int : DateTime.now().millisecondsSinceEpoch,
      status: (map['status'] ?? 'sent').toString(),
      seenAt: (map['seenAt'] is int) ? map['seenAt'] as int : null,
    );
  }

  Message copyWith({
    String? id,
    String? roomId,
    String? senderId,
    String? senderName,
    String? originalText,
    String? senderLanguage,
    int? timestamp,
    String? status,
    int? seenAt,
    String? translatedText,
    bool? isTranslating,
    bool? translationFailed,
    bool? showOriginal,
  }) {
    return Message(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      originalText: originalText ?? this.originalText,
      senderLanguage: senderLanguage ?? this.senderLanguage,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      seenAt: seenAt ?? this.seenAt,
      translatedText: translatedText ?? this.translatedText,
      isTranslating: isTranslating ?? this.isTranslating,
      translationFailed: translationFailed ?? this.translationFailed,
      showOriginal: showOriginal ?? this.showOriginal,
    );
  }
}
