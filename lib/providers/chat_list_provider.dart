import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models/chat_room_model.dart';
import '../core/models/user_model.dart';
import '../services/database_service.dart';

class ChatListProvider extends ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  List<ChatRoom> _chatRooms = [];
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<List<ChatRoom>>? _chatSubscription;
  String _searchQuery = '';

  List<ChatRoom> get chatRooms {
    if (_searchQuery.trim().isEmpty) {
      return _chatRooms;
    }
    final query = _searchQuery.toLowerCase();
    return _chatRooms.where((room) {
      final names = room.participants.values.map((p) => p.displayName.toLowerCase()).join(' ');
      return names.contains(query) || room.lastMessageText.toLowerCase().contains(query);
    }).toList();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Initialize real-time listener for current user's chats
  void initializeUserChats(String myUid) {
    _chatSubscription?.cancel();
    _isLoading = true;
    notifyListeners();

    _chatSubscription = _dbService.getUserChatRoomsStream(myUid).listen(
      (rooms) {
        _chatRooms = rooms;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        _isLoading = false;
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  /// Join chat using friend's invite code (e.g. BT-492X)
  Future<ChatRoom?> joinChatWithCode({
    required String code,
    required AppUser currentUser,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final chatRoom = await _dbService.joinChatWithInviteCode(
        code: code,
        joiningUser: currentUser,
      );
      _isLoading = false;
      notifyListeners();
      return chatRoom;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
  }
}
