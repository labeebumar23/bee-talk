import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class LanguagePickerSheet extends StatefulWidget {
  final String selectedCode;
  final ValueChanged<SupportedLanguage> onSelect;

  const LanguagePickerSheet({
    super.key,
    required this.selectedCode,
    required this.onSelect,
  });

  static Future<SupportedLanguage?> show(
    BuildContext context, {
    required String currentCode,
  }) {
    return showModalBottomSheet<SupportedLanguage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => LanguagePickerSheet(
        selectedCode: currentCode,
        onSelect: (lang) => Navigator.pop(context, lang),
      ),
    );
  }

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  String _query = '';
  late List<SupportedLanguage> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = AppConstants.languages;
  }

  void _onSearch(String value) {
    setState(() {
      _query = value.toLowerCase();
      _filtered = AppConstants.languages.where((l) {
        return l.name.toLowerCase().contains(_query) ||
            l.nativeName.toLowerCase().contains(_query) ||
            l.code.toLowerCase().contains(_query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Native Language',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pureWhite,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.beeYellow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '⚡ On-Device ML',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.beeYellow,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Bar
              TextField(
                onChanged: _onSearch,
                style: GoogleFonts.outfit(color: AppColors.pureWhite),
                decoration: InputDecoration(
                  hintText: 'Search language (e.g. Urdu, Turkish, English)...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.charcoalMuted),
                  filled: true,
                  fillColor: AppColors.charcoalDark,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.charcoalBorder),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Language List
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.charcoalBorder),
                  itemBuilder: (context, index) {
                    final lang = _filtered[index];
                    final isSelected = lang.code.toLowerCase() == widget.selectedCode.toLowerCase();

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Text(
                        lang.flag,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Row(
                        children: [
                          Text(
                            lang.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.beeYellow : AppColors.pureWhite,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${lang.nativeName})',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              color: AppColors.charcoalMuted,
                            ),
                          ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.beeYellow)
                          : null,
                      onTap: () => widget.onSelect(lang),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
