import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/chat_room_model.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../widgets/bee_avatar.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatelessWidget {
  final ChatRoom chatRoom;

  const ChatScreen({super.key, required this.chatRoom});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        chatRoom: chatRoom,
        currentUser: currentUser,
      ),
      child: const _ChatScreenContent(),
    );
  }
}

class _ChatScreenContent extends StatefulWidget {
  const _ChatScreenContent();

  @override
  State<_ChatScreenContent> createState() => _ChatScreenContentState();
}

class _ChatScreenContentState extends State<_ChatScreenContent> {
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final friend = chat.friend;
    final friendLang = friend != null
        ? AppConstants.getLanguageByCode(friend.nativeLanguage)
        : AppConstants.getDefaultLanguage();

    // Auto-scroll on new message
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            BeeAvatar(
              seed: friend?.avatarSeed ?? 'bee_friend',
              size: 38,
              isOnline: chat.isFriendOnline,
              showPresence: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend?.displayName ?? 'Friend',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pureWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Text(friendLang.flag, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 4),
                      Text(
                        "${friendLang.name} • ${chat.isFriendOnline ? 'Online' : 'Offline'}",
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: chat.isFriendOnline
                              ? AppColors.onlineGreen
                              : AppColors.charcoalMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Translation banner indicator in AppBar
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.beeYellow.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.beeYellow.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 13, color: AppColors.beeYellow),
                const SizedBox(width: 4),
                Text(
                  "Auto-Translate",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.beeYellow,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Information Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: AppColors.charcoalSurface,
            child: Text(
              "🐝 Messages are translated directly on your device via Google ML Kit",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.charcoalMuted,
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: chat.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.beeYellow),
                  )
                : chat.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🐝', style: TextStyle(fontSize: 48)),
                            const SizedBox(height: 12),
                            Text(
                              "Private Chat Room Started",
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pureWhite,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Send a message in your native language.\nIt will be translated automatically for your friend!",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.charcoalMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: chat.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chat.messages[index];
                          final isMe = msg.senderId == chat.currentUser.uid;

                          return MessageBubble(
                            message: msg,
                            isMe: isMe,
                            myLanguageCode: chat.currentUser.nativeLanguage,
                            onToggleOriginal: () => chat.toggleShowOriginal(msg.id),
                          );
                        },
                      ),
          ),

          // Chat Input Bar
          ChatInputBar(
            myLanguageCode: chat.currentUser.nativeLanguage,
            onSend: (text) => chat.sendMessage(text),
          ),
        ],
      ),
    );
  }
}
