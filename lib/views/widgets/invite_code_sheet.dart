import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import 'bee_avatar.dart';

class InviteCodeSheet extends StatelessWidget {
  final AppUser user;

  const InviteCodeSheet({super.key, required this.user});

  static void show(BuildContext context, {required AppUser user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => InviteCodeSheet(user: user),
    );
  }

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: user.inviteCode));
    Fluttertoast.showToast(
      msg: "Invite code copied to clipboard! 🐝",
      backgroundColor: AppColors.beeYellow,
      textColor: AppColors.charcoalDark,
      gravity: ToastGravity.SNACKBAR,
    );
  }

  void _shareCode() {
    final shareText =
        "Hey! Chat with me privately on Bee Talk using my invite code: ${user.inviteCode}\n"
        "Messages are translated in real-time on-device! ⚡";
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.charcoalBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Creator Avatar with glow
          BeeAvatar(seed: user.avatarSeed, size: 72),
          const SizedBox(height: 16),

          Text(
            user.displayName,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.pureWhite,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            'Share your private invite code to start chatting',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.charcoalMuted,
            ),
          ),
          const SizedBox(height: 24),

          // Code Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.charcoalDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.beeYellow.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.beeYellow.withOpacity(0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  'YOUR PRIVATE INVITE CODE',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.beeYellow,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user.inviteCode,
                  style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: AppColors.pureWhite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyCode(context),
                  icon: const Icon(Icons.copy_rounded, size: 20),
                  label: const Text('Copy Code'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareCode,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Share Link'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Privacy Note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.charcoalMuted),
              const SizedBox(width: 6),
              Text(
                '100% Invite-Only • No public directory or discovery',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.charcoalMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
