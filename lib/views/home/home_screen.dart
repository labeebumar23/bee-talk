import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/chat_room_model.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/code_generator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_list_provider.dart';
import '../chat/chat_screen.dart';
import '../widgets/bee_avatar.dart';
import '../widgets/invite_code_sheet.dart';
import '../widgets/join_code_sheet.dart';
import '../widgets/language_picker_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _quickCodeController = TextEditingController();
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser != null) {
        context.read<ChatListProvider>().initializeUserChats(auth.currentUser!.uid);
      }
    });
  }

  @override
  void dispose() {
    _quickCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickJoin() async {
    final raw = _quickCodeController.text.trim();
    if (raw.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a code (e.g. BT-492X)");
      return;
    }

    final normalized = InviteCodeUtil.normalizeCode(raw);
    if (!InviteCodeUtil.isValidCode(normalized)) {
      Fluttertoast.showToast(msg: "Invalid code format. Example: BT-492X");
      return;
    }

    setState(() => _isJoining = true);
    final auth = context.read<AuthProvider>();
    final chatList = context.read<ChatListProvider>();

    final room = await chatList.joinChatWithCode(
      code: normalized,
      joiningUser: auth.currentUser!,
    );

    setState(() => _isJoining = false);

    if (room != null && mounted) {
      _quickCodeController.clear();
      FocusScope.of(context).unfocus();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(chatRoom: room)),
      );
    } else if (mounted) {
      Fluttertoast.showToast(
        msg: chatList.errorMessage ?? "Could not find chat room.",
        backgroundColor: AppColors.errorRed,
      );
    }
  }

  void _showProfileSettings(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final lang = AppConstants.getLanguageByCode(user.nativeLanguage);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.charcoalBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              BeeAvatar(seed: user.avatarSeed, size: 68),
              const SizedBox(height: 14),
              Text(
                user.displayName,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.pureWhite,
                ),
              ),
              Text(
                "Your Code: ${user.inviteCode}",
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.beeYellow,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(lang.flag, style: const TextStyle(fontSize: 20)),
                ),
                title: Text(
                  'Native Language',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pureWhite,
                  ),
                ),
                subtitle: Text(
                  '${lang.name} (${lang.nativeName})',
                  style: GoogleFonts.outfit(color: AppColors.charcoalMuted),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.charcoalMuted),
                onTap: () async {
                  Navigator.pop(context);
                  final selected = await LanguagePickerSheet.show(
                    context,
                    currentCode: user.nativeLanguage,
                  );
                  if (selected != null) {
                    auth.updateNativeLanguage(selected.code);
                  }
                },
              ),
              const Divider(color: AppColors.charcoalBorder, height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_rounded, color: AppColors.beeYellow),
                ),
                title: Text(
                  'My Invite Code',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.pureWhite,
                  ),
                ),
                subtitle: Text(
                  user.inviteCode,
                  style: GoogleFonts.outfit(color: AppColors.charcoalMuted),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.charcoalMuted),
                onTap: () {
                  Navigator.pop(context);
                  InviteCodeSheet.show(context, user: user);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatList = context.watch<ChatListProvider>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppColors.beeYellow),
        ),
      );
    }

    final userLang = AppConstants.getLanguageByCode(user.nativeLanguage);

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.beeYellow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('🐝', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pureWhite,
                  ),
                ),
                Text(
                  "Private • On-Device Translation",
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.beeYellow,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // User Language Badge
          GestureDetector(
            onTap: () => _showProfileSettings(context),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.charcoalCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.charcoalBorder),
              ),
              child: Row(
                children: [
                  Text(userLang.flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(
                    userLang.name,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.pureWhite,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // User Avatar Button
          GestureDetector(
            onTap: () => _showProfileSettings(context),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: BeeAvatar(seed: user.avatarSeed, size: 36),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Action Cards Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Prominent 'Create Invite Link' Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.beeYellow, AppColors.beeYellowDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.beeYellow.withOpacity(0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "INVITE-ONLY PRIVACY",
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: AppColors.charcoalDark.withOpacity(0.85),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.charcoalDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                user.inviteCode,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.beeYellow,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Create Invite Link",
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.charcoalDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Share your invite code to chat in real-time across different languages.",
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.charcoalDark.withOpacity(0.85),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => InviteCodeSheet.show(context, user: user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.charcoalDark,
                            foregroundColor: AppColors.pureWhite,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.beeYellow),
                          label: Text(
                            "Share My Code / Link",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Inline 'Enter Friend's Code' Input Box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.charcoalBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.vpn_key_rounded, color: AppColors.beeYellow, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Enter Friend's Code",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.pureWhite,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _quickCodeController,
                                textCapitalization: TextCapitalization.characters,
                                style: GoogleFonts.outfit(
                                  color: AppColors.beeYellow,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'e.g. BT-492X',
                                  hintStyle: GoogleFonts.outfit(
                                    color: AppColors.charcoalMuted,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.charcoalDark,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: AppColors.charcoalBorder),
                                  ),
                                ),
                                onSubmitted: (_) => _handleQuickJoin(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _isJoining ? null : _handleQuickJoin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isJoining
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.charcoalDark),
                                      ),
                                    )
                                  : Text(
                                      "Join 🐝",
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active Chats Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Active Chats",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.charcoalCard,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${chatList.chatRooms.length} rooms",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoalMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Active Chats List
          if (chatList.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.beeYellow),
              ),
            )
          else if (chatList.chatRooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.charcoalSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.charcoalBorder),
                        ),
                        child: const Text('🍯', style: TextStyle(fontSize: 42)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No Active Conversations",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.pureWhite,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Share your invite code or enter a friend's code above to establish an encrypted, auto-translated chat.",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.charcoalMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final room = chatList.chatRooms[index];
                  final friend = room.getOtherParticipant(user.uid);
                  final friendLang = friend != null
                      ? AppConstants.getLanguageByCode(friend.nativeLanguage)
                      : AppConstants.getDefaultLanguage();

                  final timeStr = room.lastMessageTimestamp > 0
                      ? DateFormat('hh:mm a').format(
                          DateTime.fromMillisecondsSinceEpoch(room.lastMessageTimestamp),
                        )
                      : '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: BeeAvatar(
                          seed: friend?.avatarSeed ?? 'bee_friend',
                          size: 48,
                          badgeText: friendLang.flag,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                friend?.displayName ?? 'Friend',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.pureWhite,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.charcoalMuted,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.lastMessageText,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    color: AppColors.charcoalMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.beeYellow.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  friendLang.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.beeYellow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatScreen(chatRoom: room),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
                childCount: chatList.chatRooms.length,
              ),
            ),
        ],
      ),
    );
  }
}
