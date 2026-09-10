import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/message_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/translation_peek_dialog.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String myLanguageCode;
  final VoidCallback onToggleOriginal;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.myLanguageCode,
    required this.onToggleOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a').format(
      DateTime.fromMillisecondsSinceEpoch(message.timestamp),
    );

    final isDifferentLanguage = !isMe &&
        message.senderLanguage.toLowerCase() != myLanguageCode.toLowerCase();

    // Determine displayed text
    String displayText = message.originalText;
    bool isShowingTranslation = false;

    if (isDifferentLanguage) {
      if (message.showOriginal) {
        displayText = message.originalText;
        isShowingTranslation = false;
      } else if (message.translatedText != null) {
        displayText = message.translatedText!;
        isShowingTranslation = true;
      }
    }

    final senderLang = AppConstants.getLanguageByCode(message.senderLanguage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Bubble Content
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // If receiver & translated: Eye icon to peek/toggle
              if (isDifferentLanguage)
                Padding(
                  padding: const EdgeInsets.only(right: 6, bottom: 4),
                  child: InkWell(
                    onTap: () => TranslationPeekDialog.show(
                      context,
                      message: message,
                      myLanguageCode: myLanguageCode,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: message.showOriginal
                            ? AppColors.beeYellow.withOpacity(0.2)
                            : AppColors.charcoalCard,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: message.showOriginal
                              ? AppColors.beeYellow
                              : AppColors.charcoalBorder,
                          width: 1,
                        ),
                      ),
                      child: Tooltip(
                        message: "Tap to view original/translated insight",
                        child: Text(
                          '👁️',
                          style: TextStyle(
                            fontSize: 14,
                            color: message.showOriginal
                                ? AppColors.beeYellow
                                : AppColors.charcoalMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Main Message Bubble
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.76,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.beeYellow : AppColors.charcoalCard,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    border: Border.all(
                      color: isMe
                          ? AppColors.beeYellowDark
                          : AppColors.charcoalBorder,
                      width: 1,
                    ),
                    boxShadow: isMe
                        ? [
                            BoxShadow(
                              color: AppColors.beeYellow.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Translation Badge Header for Receiver
                      if (isDifferentLanguage)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(senderLang.flag,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                isShowingTranslation
                                    ? "Translated from ${senderLang.name}"
                                    : "Original (${senderLang.name})",
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isShowingTranslation
                                      ? AppColors.beeYellow
                                      : AppColors.charcoalMuted,
                                ),
                              ),
                              if (message.isTranslating) ...[
                                const SizedBox(width: 6),
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.beeYellow),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // Message Body Text
                      SelectableText(
                        displayText,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.35,
                          color: isMe
                              ? AppColors.charcoalDark
                              : AppColors.pureWhite,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Timestamp & Status
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            timeStr,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isMe
                                  ? AppColors.charcoalDark.withOpacity(0.65)
                                  : AppColors.charcoalMuted,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.done_all_rounded,
                              size: 13,
                              color: AppColors.charcoalDark.withOpacity(0.65),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
