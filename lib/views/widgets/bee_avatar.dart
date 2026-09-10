import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/avatar_generator.dart';

class BeeAvatar extends StatelessWidget {
  final String seed;
  final double size;
  final bool isOnline;
  final bool showPresence;
  final String? badgeText;

  const BeeAvatar({
    super.key,
    required this.seed,
    this.size = 48,
    this.isOnline = false,
    this.showPresence = false,
    this.badgeText,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = BeeAvatarUtil.getGradientForSeed(seed);
    final emoji = BeeAvatarUtil.getEmojiForSeed(seed);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradient[0].withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.charcoalDark,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              emoji,
              style: TextStyle(fontSize: size * 0.48),
            ),
          ),
        ),

        // Online presence indicator
        if (showPresence)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.onlineGreen : AppColors.charcoalMuted,
                border: Border.all(
                  color: AppColors.charcoalDark,
                  width: 2,
                ),
              ),
            ),
          ),

        // Optional language badge
        if (badgeText != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.charcoalSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.beeYellow, width: 1),
              ),
              child: Text(
                badgeText!,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
