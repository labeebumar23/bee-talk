import 'dart:math';

class InviteCodeUtil {
  static const String _chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // Removed confusing 0/O, 1/I

  static String generateCode() {
    final random = Random.secure();
    final buffer = StringBuffer('BT-');
    for (int i = 0; i < 4; i++) {
      buffer.write(_chars[random.nextInt(_chars.length)]);
    }
    return buffer.toString();
  }

  static String normalizeCode(String input) {
    String cleaned = input.trim().toUpperCase().replaceAll(' ', '');
    if (!cleaned.startsWith('BT-') && cleaned.length == 4) {
      cleaned = 'BT-$cleaned';
    }
    return cleaned;
  }

  static bool isValidCode(String code) {
    final normalized = normalizeCode(code);
    final regExp = RegExp(r'^BT-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{4}$');
    return regExp.hasMatch(normalized);
  }
}
