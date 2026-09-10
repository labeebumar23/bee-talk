import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/message_model.dart';
import '../../core/theme/app_theme.dart';

class TranslationPeekDialog extends StatelessWidget {
  final Message message;
  final String myLanguageCode;

  const TranslationPeekDialog({
    super.key,
    required this.message,
    required this.myLanguageCode,
  });

  static void show(
    BuildContext context, {
    required Message message,
    required String myLanguageCode,
  }) {
    showDialog(
      context: context,
      builder: (context) => TranslationPeekDialog(
        message: message,
        myLanguageCode: myLanguageCode,
      ),
    );
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: "$label copied to clipboard!",
      backgroundColor: AppColors.beeYellow,
      textColor: AppColors.charcoalDark,
      gravity: ToastGravity.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderLang = AppConstants.getLanguageByCode(message.senderLanguage);
    final myLang = AppConstants.getLanguageByCode(myLanguageCode);

    return Dialog(
      backgroundColor: AppColors.charcoalSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.charcoalBorder, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('👁️', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      'Translation Insight',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.pureWhite,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.charcoalMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Original Text Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.charcoalDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.charcoalBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(senderLang.flag, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
                            'ORIGINAL (${senderLang.name.toUpperCase()})',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: AppColors.charcoalMuted,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _copy(message.originalText, 'Original text'),
                        child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.charcoalMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    message.originalText,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: AppColors.pureWhite,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Translated Text Card
            if (message.translatedText != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.beeYellow.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.beeYellow.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(myLang.flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 6),
                            Text(
                              'TRANSLATED (${myLang.name.toUpperCase()})',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: AppColors.beeYellow,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => _copy(message.translatedText!, 'Translated text'),
                          child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.beeYellow),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      message.translatedText!,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.pureWhite,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Footer info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded, size: 14, color: AppColors.beeYellow),
                const SizedBox(width: 4),
                Text(
                  'Powered by On-Device Google ML Kit (Offline)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.charcoalMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
