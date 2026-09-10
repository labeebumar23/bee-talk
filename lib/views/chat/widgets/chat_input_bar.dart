import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final String myLanguageCode;
  final ValueChanged<String> onSend;

  const ChatInputBar({
    super.key,
    required this.myLanguageCode,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSend) {
        setState(() => _canSend = can);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final myLang = AppConstants.getLanguageByCode(widget.myLanguageCode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.charcoalSurface,
        border: const Border(
          top: BorderSide(color: AppColors.charcoalBorder, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language Badge Indicator
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  Text(myLang.flag, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    "Sending as ${myLang.name} (${myLang.nativeName})",
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.charcoalMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.lock_rounded, size: 11, color: AppColors.charcoalMuted),
                  const SizedBox(width: 3),
                  Text(
                    "On-device translated",
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.charcoalMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Input Row
            Row(
              children: [
                // Text Field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.charcoalDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.charcoalBorder),
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.outfit(
                        color: AppColors.pureWhite,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your message...',
                        hintStyle: GoogleFonts.outfit(
                          color: AppColors.charcoalMuted,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Glowing Send Button
                GestureDetector(
                  onTap: _canSend ? _handleSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _canSend ? AppColors.beeYellow : AppColors.charcoalCard,
                      boxShadow: _canSend
                          ? [
                              BoxShadow(
                                color: AppColors.beeYellow.withOpacity(0.35),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      size: 20,
                      color: _canSend ? AppColors.charcoalDark : AppColors.charcoalMuted,
                    ),
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
