import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/code_generator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_list_provider.dart';
import '../chat/chat_screen.dart';

class JoinCodeSheet extends StatefulWidget {
  const JoinCodeSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => const JoinCodeSheet(),
    );
  }

  @override
  State<JoinCodeSheet> createState() => _JoinCodeSheetState();
}

class _JoinCodeSheetState extends State<JoinCodeSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final rawInput = _codeController.text.trim();
    if (rawInput.isEmpty) {
      setState(() => _error = 'Please enter an invite code.');
      return;
    }

    final normalized = InviteCodeUtil.normalizeCode(rawInput);
    if (!InviteCodeUtil.isValidCode(normalized)) {
      setState(() => _error = 'Code must be in format BT-XXXX (e.g. BT-492X).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final chatList = context.read<ChatListProvider>();

    if (auth.currentUser == null) return;

    final chatRoom = await chatList.joinChatWithCode(
      code: normalized,
      joiningUser: auth.currentUser!,
    );

    setState(() => _isSubmitting = false);

    if (chatRoom != null && mounted) {
      Navigator.pop(context); // Close sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(chatRoom: chatRoom),
        ),
      );
    } else if (mounted) {
      setState(() {
        _error = chatList.errorMessage ?? 'Could not join chat room.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.charcoalBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.beeYellow.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_rounded, color: AppColors.beeYellow, size: 24),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Enter Friend's Code",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  Text(
                    "Connect instantly in a private room",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.charcoalMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Code Input Field
          TextField(
            controller: _codeController,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: AppColors.beeYellow,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'BT-492X',
              hintStyle: GoogleFonts.outfit(
                color: AppColors.charcoalMuted,
                letterSpacing: 2,
              ),
              errorText: _error,
              filled: true,
              fillColor: AppColors.charcoalDark,
            ),
            onSubmitted: (_) => _handleJoin(),
          ),
          const SizedBox(height: 20),

          // Submit Button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleJoin,
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.charcoalDark),
                    ),
                  )
                : const Text('Start Private Chat 🐝'),
          ),
        ],
      ),
    );
  }
}
