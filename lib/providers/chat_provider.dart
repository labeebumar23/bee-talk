import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/chat_room_model.dart';
import '../core/models/message_model.dart';
import '../core/models/user_model.dart';
import '../services/database_service.dart';
import '../services/translation_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final TranslationService _translationService = TranslationService();

  final ChatRoom chatRoom;
  final AppUser currentUser;

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isFriendOnline = false;
  String? _errorMessage;

  StreamSubscription<List<Message>>? _messageSubscription;
  StreamSubscription<bool>? _presenceSubscription;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isFriendOnline => _isFriendOnline;
  String? get errorMessage => _errorMessage;

  ChatParticipant? get friend => chatRoom.getOtherParticipant(currentUser.uid);

  ChatProvider({
    required this.chatRoom,
    required this.currentUser,
  }) {
    _initChat();
  }

  void _initChat() {
    _isLoading = true;
    notifyListeners();

    // Listen to friend's presence
    if (friend != null) {
      _presenceSubscription = _dbService
          .getUserOnlineStatusStream(friend!.uid)
          .listen((online) {
        _isFriendOnline = online;
        notifyListeners();
      });
    }

    // Listen to real-time messages
    _messageSubscription = _dbService
        .getMessagesStream(chatRoom.roomId)
        .listen((incomingMessages) async {
      _messages = incomingMessages;
      _isLoading = false;
      notifyListeners();

      // Trigger automatic background on-device translation for incoming messages
      _translateIncomingMessages();
    }, onError: (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    });
  }

  /// Automatically translates messages sent by other participants into current user's native language
  Future<void> _translateIncomingMessages() async {
    for (final msg in _messages) {
      // If message is from another user and in a different language
      if (msg.senderId != currentUser.uid &&
          msg.senderLanguage.toLowerCase() != currentUser.nativeLanguage.toLowerCase()) {
        
        if (msg.translatedText == null && !msg.isTranslating) {
          msg.isTranslating = true;
          notifyListeners();

          try {
            final translated = await _translationService.translate(
              text: msg.originalText,
              sourceLangCode: msg.senderLanguage,
              targetLangCode: currentUser.nativeLanguage,
            );
            msg.translatedText = translated;
            msg.isTranslating = false;
          } catch (e) {
            msg.translationFailed = true;
            msg.isTranslating = false;
          }
          notifyListeners();
        }
      }
    }
  }

  /// Toggle showing the original untranslated text (Eye 👁️ Icon feature)
  void toggleShowOriginal(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index].showOriginal = !_messages[index].showOriginal;
      notifyListeners();
    }
  }

  /// Send message
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await _dbService.sendMessage(
        roomId: chatRoom.roomId,
        sender: currentUser,
        text: text,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _presenceSubscription?.cancel();
    super.dispose();
  }
}
