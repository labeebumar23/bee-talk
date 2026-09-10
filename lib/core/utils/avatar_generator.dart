import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BeeAvatarUtil {
  static const List<String> beeMoods = [
    '🐝', '🍯', '👑', '⚡', '✨', '🌻', '🚀', '🌟', '💫', '🔥'
  ];

  static const List<List<Color>> beeGradients = [
    [Color(0xFFFFB800), Color(0xFFF59E0B)],
    [Color(0xFFFFD54F), Color(0xFFFFB300)],
    [Color(0xFFFCD34D), Color(0xFFD97706)],
    [Color(0xFFFEF08A), Color(0xFFCA8A04)],
    [Color(0xFFFFE082), Color(0xFFFF8F00)],
  ];

  static List<Color> getGradientForSeed(String seed) {
    if (seed.isEmpty) return beeGradients[0];
    final hash = seed.codeUnits.fold(0, (prev, elem) => prev + elem);
    return beeGradients[hash % beeGradients.length];
  }

  static String getEmojiForSeed(String seed) {
    if (seed.isEmpty) return '🐝';
    final hash = seed.codeUnits.fold(0, (prev, elem) => prev + elem);
    return beeMoods[hash % beeMoods.length];
  }

  static String generateRandomSeed() {
    final random = Random();
    return 'bee_${random.nextInt(10000)}';
  }
}
