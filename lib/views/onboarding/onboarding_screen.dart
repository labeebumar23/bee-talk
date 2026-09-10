import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/avatar_generator.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import '../widgets/bee_avatar.dart';
import '../widgets/language_picker_sheet.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  late SupportedLanguage _selectedLanguage;
  late String _avatarSeed;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    // Default to Urdu or English for showcase
    _selectedLanguage = AppConstants.getLanguageByCode('ur');
    _avatarSeed = BeeAvatarUtil.generateRandomSeed();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _randomizeAvatar() {
    setState(() {
      _avatarSeed = BeeAvatarUtil.generateRandomSeed();
    });
  }

  Future<void> _handleSubmit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter your display name.');
      return;
    }

    if (name.length < 2) {
      setState(() => _nameError = 'Display name must be at least 2 characters.');
      return;
    }

    setState(() => _nameError = null);

    final auth = context.read<AuthProvider>();
    final success = await auth.completeOnboarding(
      displayName: name,
      nativeLanguage: _selectedLanguage.code,
      avatarSeed: _avatarSeed,
    );

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.charcoalDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing Bumblebee Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.beeYellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.beeYellow.withOpacity(0.4),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🐝', style: TextStyle(fontSize: 44)),
                    ),
                  ),
                ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 16),

                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.pureWhite,
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 6),

                Text(
                  AppConstants.appTagline,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.charcoalMuted,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 28),

                // Interactive Avatar Section
                Center(
                  child: GestureDetector(
                    onTap: _randomizeAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        BeeAvatar(seed: _avatarSeed, size: 84),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.beeYellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.charcoalDark, width: 2),
                          ),
                          child: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.charcoalDark),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Tap to shuffle avatar mood",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.charcoalMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Setup Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.charcoalBorder, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Step 1: Display Name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.beeYellow.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "STEP 1",
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.beeYellow,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Display Name",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.pureWhite,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        style: GoogleFonts.outfit(color: AppColors.pureWhite, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'e.g. Alex, Zeynep, Hamza',
                          errorText: _nameError,
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.charcoalMuted),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Step 2: Native Language Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.beeYellow.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "STEP 2",
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.beeYellow,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Your Native Language",
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.pureWhite,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () async {
                              final selected = await LanguagePickerSheet.show(
                                context,
                                currentCode: _selectedLanguage.code,
                              );
                              if (selected != null) {
                                setState(() => _selectedLanguage = selected);
                              }
                            },
                            child: Text(
                              "View All 50+",
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.beeYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Language Dropdown Selector Field
                      InkWell(
                        onTap: () async {
                          final selected = await LanguagePickerSheet.show(
                            context,
                            currentCode: _selectedLanguage.code,
                          );
                          if (selected != null) {
                            setState(() => _selectedLanguage = selected);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.charcoalDark,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.charcoalBorder),
                          ),
                          child: Row(
                            children: [
                              Text(_selectedLanguage.flag, style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedLanguage.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.pureWhite,
                                      ),
                                    ),
                                    Text(
                                      _selectedLanguage.nativeName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: AppColors.charcoalMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.charcoalCard,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Change",
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.beeYellow,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: AppColors.beeYellow, size: 18),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                // Error Banner
                if (auth.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.errorRed.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.errorRed),
                      ),
                      child: Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(color: AppColors.errorRed, fontSize: 13),
                      ),
                    ),
                  ),

                // Start Chatting Button
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.charcoalDark),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Start Chatting",
                              style: GoogleFonts.outfit(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('🐝', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 18),

                // Zero-Friction Info Note
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security_rounded, size: 15, color: AppColors.charcoalMuted),
                    const SizedBox(width: 6),
                    Text(
                      "Anonymous ID • 100% Private • On-Device ML Kit",
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.charcoalMuted,
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 350.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
