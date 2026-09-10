import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ==========================================
// 🚀 APP ENTRY & FIREBASE INITIALIZATION
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyDjubRpVMJjlj7jFqm2oVovgO7h7upnR6s",
      authDomain: "bee-talk-bd4a6.firebaseapp.com",
      databaseURL: "https://bee-talk-bd4a6-default-rtdb.firebaseio.com",
      projectId: "bee-talk-bd4a6",
      storageBucket: "bee-talk-bd4a6.firebasestorage.app",
      messagingSenderId: "994926166121",
      appId: "1:994926166121:web:7e5a347ab1a1924b1962f8",
      measurementId: "G-Z6WKLFNY0G",
    ),
  );

  runApp(const BeeTalkApp());
}

// ==========================================
// 🎨 BUMBLEBEE DESIGN SYSTEM & COLOR PALETTE
// ==========================================
class BeeColors {
  static const Color yellow = Color(0xFFFFC107);
  static const Color yellowAccent = Color(0xFFFFD54F);
  static const Color yellowDark = Color(0xFFFFA000);

  static const Color charcoal = Color(0xFF181810);
  static const Color charcoalSurface = Color(0xFF22221A);
  static const Color charcoalCard = Color(0xFF2C2C24);
  static const Color charcoalBorder = Color(0xFF3D3D32);
  static const Color charcoalMuted = Color(0xFF8E8E80);

  static const Color white = Color(0xFFFFFFFF);
  static const Color whiteOff = Color(0xFFF8F9FA);
  static const Color onlineGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
}

// ==========================================
// 🌐 REAL-TIME DYNAMIC TRANSLATION ENGINE
// ==========================================
class RealtimeTranslator {
  static final Map<String, String> _cache = {};

  static String extractLangCode(String langStr) {
    final clean = langStr.toLowerCase();
    if (clean.contains('urdu') || clean.contains('ur')) return 'ur';
    if (clean.contains('turkish') || clean.contains('türkçe') || clean.contains('tr')) return 'tr';
    if (clean.contains('english') || clean.contains('en')) return 'en';
    if (clean.contains('spanish') || clean.contains('español') || clean.contains('es')) return 'es';
    if (clean.contains('arabic') || clean.contains('العربية') || clean.contains('ar')) return 'ar';
    if (clean.contains('japanese') || clean.contains('日本語') || clean.contains('ja')) return 'ja';
    if (clean.contains('german') || clean.contains('deutsch') || clean.contains('de')) return 'de';
    if (clean.contains('french') || clean.contains('français') || clean.contains('fr')) return 'fr';
    return langStr.trim().split(' ')[0].toLowerCase();
  }

  static Future<String> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return text;

    final src = extractLangCode(sourceLang);
    final tgt = extractLangCode(targetLang);

    if (src == tgt) return trimmed;

    final cacheKey = '${src}_${tgt}_$trimmed';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final url = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$src&tl=$tgt&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> json = jsonDecode(response.body);
        if (json.isNotEmpty && json[0] is List) {
          final buffer = StringBuffer();
          for (final item in json[0]) {
            if (item is List && item.isNotEmpty && item[0] != null) {
              buffer.write(item[0].toString());
            }
          }
          final result = buffer.toString().trim();
          if (result.isNotEmpty) {
            _cache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('Real-time translation error: $e');
    }

    return trimmed;
  }
}

// ==========================================
// 📱 MAIN APPLICATION ENTRY WIDGET
// ==========================================
class BeeTalkApp extends StatelessWidget {
  const BeeTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bee Talk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BeeColors.charcoal,
        primaryColor: BeeColors.yellow,
        colorScheme: const ColorScheme.dark(
          primary: BeeColors.yellow,
          surface: BeeColors.charcoalSurface,
          onPrimary: BeeColors.charcoal,
          onSurface: BeeColors.white,
        ),
      ),
      home: const OnboardingScreen(),
    );
  }
}

// ==========================================
// 📦 USER & CHAT DATA MODELS
// ==========================================
class AppUser {
  final String uid;
  final String displayName;
  final String nativeLanguage;
  final String avatar;
  final String inviteCode;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.nativeLanguage,
    required this.avatar,
    required this.inviteCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'nativeLanguage': nativeLanguage,
      'avatar': avatar,
      'inviteCode': inviteCode,
      'isOnline': true,
      'lastSeen': ServerValue.timestamp,
    };
  }
}

class ChatRoomItem {
  final String roomId;
  final String otherUid;
  final String otherName;
  final String otherAvatar;
  final String otherLang;
  final String lastMessage;
  final int lastTimestamp;

  ChatRoomItem({
    required this.roomId,
    required this.otherUid,
    required this.otherName,
    required this.otherAvatar,
    required this.otherLang,
    required this.lastMessage,
    required this.lastTimestamp,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String sender;
  final String senderAvatar;
  final String originalText;
  String translatedText;
  final String senderLang;
  final String time;
  final int timestamp;
  final bool isMe;
  bool showOriginal;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.sender,
    required this.senderAvatar,
    required this.originalText,
    required this.translatedText,
    required this.senderLang,
    required this.time,
    required this.timestamp,
    required this.isMe,
    this.showOriginal = false,
  });
}

// ==========================================
// 🚀 SCREEN 1: ONBOARDING WITH ANONYMOUS AUTH
// ==========================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Hamza');
  String _selectedLanguage = 'Urdu (اردو) 🇵🇰';
  int _avatarIndex = 0;
  String? _error;
  bool _isLoading = false;

  final List<String> _languages = [
    'Urdu (اردو) 🇵🇰',
    'Turkish (Türkçe) 🇹🇷',
    'English (English) 🇺🇸',
    'Spanish (Español) 🇪🇸',
    'Arabic (العربية) 🇸🇦',
    'Japanese (日本語) 🇯🇵',
    'German (Deutsch) 🇩🇪',
    'French (Français) 🇫🇷',
  ];

  final List<String> _avatars = ['🐝', '🍯', '👑', '⚡', '🌻', '🚀', '✨'];

  void _shuffleAvatar() {
    setState(() {
      _avatarIndex = (_avatarIndex + 1) % _avatars.length;
    });
  }

  String _generateInviteCode() {
    final chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final randomPart = List.generate(4, (i) => chars[(DateTime.now().millisecondsSinceEpoch + i * 7) % chars.length]).join();
    return 'BT-$randomPart';
  }

  Future<void> _handleStart() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your display name');
      return;
    }

    setState(() {
      _error = null;
      _isLoading = true;
    });

    try {
      final auth = FirebaseAuth.instance;
      UserCredential userCredential;
      if (auth.currentUser == null) {
        userCredential = await auth.signInAnonymously();
      } else {
        userCredential = await auth.signInAnonymously();
      }

      final uid = userCredential.user?.uid ?? auth.currentUser?.uid;
      if (uid == null) throw Exception("Failed to acquire user ID.");

      final avatar = _avatars[_avatarIndex];
      final inviteCode = _generateInviteCode();

      final currentUser = AppUser(
        uid: uid,
        displayName: name,
        nativeLanguage: _selectedLanguage,
        avatar: avatar,
        inviteCode: inviteCode,
      );

      final dbRef = FirebaseDatabase.instance.ref();
      
      // Save User Profile
      await dbRef.child('users').child(uid).set(currentUser.toMap());

      // Register Invite Code
      await dbRef.child('invites').child(inviteCode).set({
        'code': inviteCode,
        'creatorUid': uid,
        'creatorName': name,
        'creatorAvatar': avatar,
        'creatorLang': _selectedLanguage,
        'createdAt': ServerValue.timestamp,
      });

      // Setup Realtime Presence
      final presenceRef = dbRef.child('presence').child(uid);
      dbRef.child('.info/connected').onValue.listen((event) {
        if (event.snapshot.value == true) {
          presenceRef.onDisconnect().set({
            'isOnline': false,
            'lastSeen': ServerValue.timestamp,
          });
          presenceRef.set({
            'isOnline': true,
            'lastSeen': ServerValue.timestamp,
          });
        }
      });

      if (!mounted) return;

      // Navigate to Inbox Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => InboxScreen(currentUser: currentUser),
        ),
      );
    } catch (e) {
      debugPrint('Firebase Login Error: $e');
      if (mounted) {
        setState(() => _error = 'Firebase error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: BeeColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeColors.charcoal,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: BeeColors.yellow,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: BeeColors.yellow.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🐝', style: TextStyle(fontSize: 44)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Bee Talk',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: BeeColors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Speak Free. Understand Instantly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: BeeColors.charcoalMuted,
                  ),
                ),
                const SizedBox(height: 32),

                // Avatar Mood Picker
                Center(
                  child: GestureDetector(
                    onTap: _shuffleAvatar,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [BeeColors.yellowAccent, BeeColors.yellowDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: BeeColors.charcoal, width: 3),
                          ),
                          child: Center(
                            child: Text(
                              _avatars[_avatarIndex],
                              style: const TextStyle(fontSize: 38),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: BeeColors.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(color: BeeColors.charcoal, width: 2),
                          ),
                          child: const Icon(Icons.refresh, size: 14, color: BeeColors.charcoal),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Tap avatar to change mood',
                    style: TextStyle(fontSize: 12, color: BeeColors.charcoalMuted),
                  ),
                ),
                const SizedBox(height: 28),

                // Setup Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: BeeColors.charcoalSurface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: BeeColors.charcoalBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Display Name',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BeeColors.white),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        style: const TextStyle(color: BeeColors.white, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Enter your name...',
                          hintStyle: const TextStyle(color: BeeColors.charcoalMuted),
                          prefixIcon: const Icon(Icons.person_outline, color: BeeColors.yellow),
                          filled: true,
                          fillColor: BeeColors.charcoal,
                          errorText: _error,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: BeeColors.charcoalBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: BeeColors.charcoalBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: BeeColors.yellow, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Your Native Language',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BeeColors.white),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: BeeColors.charcoal,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: BeeColors.charcoalBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            isExpanded: true,
                            dropdownColor: BeeColors.charcoalSurface,
                            icon: const Icon(Icons.keyboard_arrow_down, color: BeeColors.yellow),
                            items: _languages.map((String lang) {
                              return DropdownMenuItem<String>(
                                value: lang,
                                child: Text(
                                  lang,
                                  style: const TextStyle(color: BeeColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? val) {
                              if (val != null) setState(() => _selectedLanguage = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleStart,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BeeColors.yellow,
                    foregroundColor: BeeColors.charcoal,
                    disabledBackgroundColor: BeeColors.yellow.withOpacity(0.5),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(BeeColors.charcoal)),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Start Chat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            SizedBox(width: 8),
                            Text('🐝', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                ),
                const SizedBox(height: 18),

                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: BeeColors.charcoalMuted),
                    SizedBox(width: 6),
                    Text('Invite-to-Chat • Dynamic Real-Time Translation', style: TextStyle(fontSize: 12, color: BeeColors.charcoalMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 📥 SCREEN 2: INBOX & MULTIPLE CHATS (HOME)
// ==========================================
class InboxScreen extends StatefulWidget {
  final AppUser currentUser;

  const InboxScreen({super.key, required this.currentUser});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final List<ChatRoomItem> _chatRooms = [];
  bool _isLoading = true;
  StreamSubscription<DatabaseEvent>? _userChatsSubscription;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _listenToUserChats();
  }

  void _listenToUserChats() {
    final dbRef = FirebaseDatabase.instance.ref();
    final userChatsRef = dbRef.child('user_chats').child(widget.currentUser.uid);

    _userChatsSubscription = userChatsRef.onValue.listen((event) async {
      if (!mounted) return;
      if (!event.snapshot.exists || event.snapshot.value == null) {
        setState(() {
          _chatRooms.clear();
          _isLoading = false;
        });
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<ChatRoomItem> rooms = [];

      for (final entry in data.entries) {
        final roomId = entry.key.toString();
        final roomSnap = await dbRef.child('chat_rooms').child(roomId).get();

        if (roomSnap.exists && roomSnap.value is Map) {
          final roomData = Map<dynamic, dynamic>.from(roomSnap.value as Map);
          final participants = roomData['participants'] as Map? ?? {};
          
          String otherUid = '';
          String otherName = 'Bee User';
          String otherAvatar = '🐝';
          String otherLang = 'English';

          participants.forEach((k, v) {
            if (k.toString() != widget.currentUser.uid && v is Map) {
              otherUid = k.toString();
              otherName = v['displayName']?.toString() ?? 'Bee User';
              otherAvatar = v['avatar']?.toString() ?? '🐝';
              otherLang = v['nativeLanguage']?.toString() ?? 'English';
            }
          });

          final lastMessage = roomData['lastMessageText']?.toString() ?? 'Chat connected 🐝';
          final lastTimestamp = (roomData['lastMessageTimestamp'] is int) ? roomData['lastMessageTimestamp'] as int : 0;

          rooms.add(ChatRoomItem(
            roomId: roomId,
            otherUid: otherUid,
            otherName: otherName,
            otherAvatar: otherAvatar,
            otherLang: otherLang,
            lastMessage: lastMessage,
            lastTimestamp: lastTimestamp,
          ));
        }
      }

      rooms.sort((a, b) => b.lastTimestamp.compareTo(a.lastTimestamp));

      if (mounted) {
        setState(() {
          _chatRooms.clear();
          _chatRooms.addAll(rooms);
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _userChatsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _showNewChatDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: BeeColors.charcoalSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: BeeColors.charcoalBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const Text(
                    '🐝 New Chat',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: BeeColors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Connect with another person using their Invite Code.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: BeeColors.charcoalMuted),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: BeeColors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 2),
                    decoration: InputDecoration(
                      hintText: 'Enter Code (e.g. BT-492X)',
                      hintStyle: const TextStyle(color: BeeColors.charcoalMuted, letterSpacing: 0, fontSize: 14),
                      prefixIcon: const Icon(Icons.qr_code, color: BeeColors.yellow),
                      filled: true,
                      fillColor: BeeColors.charcoal,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BeeColors.charcoalBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: BeeColors.yellow, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      final code = codeController.text.trim().toUpperCase();
                      if (code.isEmpty) return;

                      setModalState(() => isSubmitting = true);

                      try {
                        final dbRef = FirebaseDatabase.instance.ref();
                        final inviteSnap = await dbRef.child('invites').child(code).get();

                        if (!inviteSnap.exists || inviteSnap.value == null) {
                          throw Exception("Invalid invite code. Please check and try again.");
                        }

                        final inviteData = Map<dynamic, dynamic>.from(inviteSnap.value as Map);
                        final creatorUid = inviteData['creatorUid'].toString();

                        if (creatorUid == widget.currentUser.uid) {
                          throw Exception("You cannot use your own invite code.");
                        }

                        final sortedUids = [widget.currentUser.uid, creatorUid]..sort();
                        final roomId = 'room_${sortedUids[0]}_${sortedUids[1]}';

                        final creatorName = inviteData['creatorName']?.toString() ?? 'Bee User';
                        final creatorAvatar = inviteData['creatorAvatar']?.toString() ?? '🐝';
                        final creatorLang = inviteData['creatorLang']?.toString() ?? 'English';

                        final roomPayload = {
                          'roomId': roomId,
                          'participantUids': sortedUids,
                          'participants': {
                            widget.currentUser.uid: {
                              'uid': widget.currentUser.uid,
                              'displayName': widget.currentUser.displayName,
                              'nativeLanguage': widget.currentUser.nativeLanguage,
                              'avatar': widget.currentUser.avatar,
                            },
                            creatorUid: {
                              'uid': creatorUid,
                              'displayName': creatorName,
                              'nativeLanguage': creatorLang,
                              'avatar': creatorAvatar,
                            },
                          },
                          'lastMessageText': 'Chat established 🐝',
                          'lastMessageSenderId': widget.currentUser.uid,
                          'lastMessageTimestamp': ServerValue.timestamp,
                          'createdAt': ServerValue.timestamp,
                        };

                        await dbRef.child('chat_rooms').child(roomId).set(roomPayload);
                        await dbRef.child('user_chats').child(widget.currentUser.uid).child(roomId).set({'roomId': roomId});
                        await dbRef.child('user_chats').child(creatorUid).child(roomId).set({'roomId': roomId});

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              roomId: roomId,
                              currentUser: widget.currentUser,
                              otherUid: creatorUid,
                              otherName: creatorName,
                              otherAvatar: creatorAvatar,
                              otherLang: creatorLang,
                            ),
                          ),
                        );
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: BeeColors.errorRed),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: BeeColors.yellow,
                      foregroundColor: BeeColors.charcoal,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(BeeColors.charcoal)))
                        : const Text('Connect & Chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(height: 20),

                  const Divider(color: BeeColors.charcoalBorder),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Invite Code', style: TextStyle(fontSize: 12, color: BeeColors.charcoalMuted)),
                          Text(widget.currentUser.inviteCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BeeColors.yellow, letterSpacing: 1.5)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.currentUser.inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Code ${widget.currentUser.inviteCode} copied to clipboard! 🐝'), backgroundColor: BeeColors.yellow),
                          );
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: BeeColors.charcoalCard, foregroundColor: BeeColors.white),
                        icon: const Icon(Icons.copy, size: 16, color: BeeColors.yellow),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRooms = _chatRooms.where((room) {
      if (_searchQuery.isEmpty) return true;
      return room.otherName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             room.lastMessage.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: BeeColors.charcoal,
      appBar: AppBar(
        backgroundColor: BeeColors.charcoal,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [BeeColors.yellowAccent, BeeColors.yellowDark]),
              ),
              child: Center(child: Text(widget.currentUser.avatar, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.currentUser.displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: BeeColors.white)),
                Text("Code: ${widget.currentUser.inviteCode}", style: const TextStyle(fontSize: 11, color: BeeColors.yellow, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: BeeColors.yellow),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.currentUser.inviteCode));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Your Invite Code ${widget.currentUser.inviteCode} copied!'), backgroundColor: BeeColors.yellow),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showNewChatDialog,
        backgroundColor: BeeColors.yellow,
        foregroundColor: BeeColors.charcoal,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
        label: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: BeeColors.charcoalSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: BeeColors.charcoalBorder),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: BeeColors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search conversations...',
                  hintStyle: TextStyle(color: BeeColors.charcoalMuted, fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: BeeColors.charcoalMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),

          // Privacy Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: BeeColors.charcoalSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BeeColors.yellow.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: BeeColors.yellow),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🔒 Dynamic Instant Translation • Monthly Auto-Clear Active (30 days)',
                    style: TextStyle(fontSize: 11, color: BeeColors.charcoalMuted),
                  ),
                ),
              ],
            ),
          ),

          // Inbox List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: BeeColors.yellow))
                : filteredRooms.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🐝', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text('No Chats Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BeeColors.white)),
                              const SizedBox(height: 6),
                              Text(
                                'Share your invite code (${widget.currentUser.inviteCode}) or tap "+ New Chat" to start your first cross-language conversation!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: BeeColors.charcoalMuted),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: _showNewChatDialog,
                                style: ElevatedButton.styleFrom(backgroundColor: BeeColors.yellow, foregroundColor: BeeColors.charcoal),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Start First Chat', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredRooms.length,
                        separatorBuilder: (ctx, i) => const Divider(color: BeeColors.charcoalBorder, height: 1),
                        itemBuilder: (ctx, index) {
                          final room = filteredRooms[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            leading: Stack(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BeeColors.charcoalCard,
                                  ),
                                  child: Center(child: Text(room.otherAvatar, style: const TextStyle(fontSize: 24))),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: BeeColors.onlineGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: BeeColors.charcoal, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(room.otherName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: BeeColors.white)),
                                Text(
                                  room.otherLang.split(' ')[0],
                                  style: const TextStyle(fontSize: 11, color: BeeColors.yellow, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                room.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: BeeColors.charcoalMuted),
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    roomId: room.roomId,
                                    currentUser: widget.currentUser,
                                    otherUid: room.otherUid,
                                    otherName: room.otherName,
                                    otherAvatar: room.otherAvatar,
                                    otherLang: room.otherLang,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 💬 SCREEN 3: 1-ON-1 CHAT ROOM
// ==========================================
class ChatScreen extends StatefulWidget {
  final String roomId;
  final AppUser currentUser;
  final String otherUid;
  final String otherName;
  final String otherAvatar;
  final String otherLang;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.currentUser,
    required this.otherUid,
    required this.otherName,
    required this.otherAvatar,
    required this.otherLang,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  late DatabaseReference _messagesRef;
  StreamSubscription<DatabaseEvent>? _messagesSubscription;

  static const int monthlyRetentionMs = 30 * 24 * 60 * 60 * 1000;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  void _initChat() {
    final db = FirebaseDatabase.instance;
    _messagesRef = db.ref('messages').child(widget.roomId);

    final cutoffTimestamp = DateTime.now().millisecondsSinceEpoch - monthlyRetentionMs;

    _messagesSubscription = _messagesRef.orderByChild('timestamp').onValue.listen((event) async {
      if (!mounted) return;
      if (!event.snapshot.exists || event.snapshot.value == null) {
        setState(() => _messages.clear());
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final List<ChatMessage> activeMessages = [];
      final List<String> expiredIds = [];

      for (final entry in data.entries) {
        final key = entry.key.toString();
        final val = entry.value;

        if (val is Map) {
          final timestamp = (val['timestamp'] is int) ? val['timestamp'] as int : DateTime.now().millisecondsSinceEpoch;
          
          if (timestamp >= cutoffTimestamp) {
            final senderId = (val['senderId'] ?? '').toString();
            final isMe = senderId == widget.currentUser.uid;
            final originalText = (val['text'] ?? '').toString();
            final senderLang = (val['senderLang'] ?? widget.otherLang).toString();

            String translated = originalText;
            if (!isMe) {
              translated = await RealtimeTranslator.translate(
                text: originalText,
                sourceLang: senderLang,
                targetLang: widget.currentUser.nativeLanguage,
              );
            }

            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
            final period = date.hour >= 12 ? 'PM' : 'AM';
            final minute = date.minute.toString().padLeft(2, '0');
            final formattedTime = "$hour:$minute $period";

            activeMessages.add(ChatMessage(
              id: key,
              senderId: senderId,
              sender: (val['senderName'] ?? 'Bee User').toString(),
              senderAvatar: (val['senderAvatar'] ?? '🐝').toString(),
              originalText: originalText,
              translatedText: translated,
              senderLang: senderLang,
              time: formattedTime,
              timestamp: timestamp,
              isMe: isMe,
            ));
          } else {
            expiredIds.add(key);
          }
        }
      }

      // Prune messages older than 30 days
      for (final id in expiredIds) {
        _messagesRef.child(id).remove();
      }

      activeMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(activeMessages);
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      final newMsgRef = _messagesRef.push();
      await newMsgRef.set({
        'senderId': widget.currentUser.uid,
        'senderName': widget.currentUser.displayName,
        'senderAvatar': widget.currentUser.avatar,
        'senderLang': widget.currentUser.nativeLanguage,
        'text': text,
        'timestamp': timestamp,
      });

      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('chat_rooms').child(widget.roomId).update({
        'lastMessageText': text,
        'lastMessageSenderId': widget.currentUser.uid,
        'lastMessageTimestamp': timestamp,
      });

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showTranslationInsight(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: BeeColors.charcoalSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: BeeColors.charcoalBorder)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Text('👁️', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 8),
                        Text('Translation Insight', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: BeeColors.white)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: BeeColors.charcoalMuted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: BeeColors.charcoal, borderRadius: BorderRadius.circular(12), border: Border.all(color: BeeColors.charcoalBorder)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORIGINAL (${msg.senderLang.split(' ')[0].toUpperCase()})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BeeColors.charcoalMuted)),
                      const SizedBox(height: 6),
                      Text(msg.originalText, style: const TextStyle(fontSize: 15, color: BeeColors.white)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: BeeColors.yellow.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: BeeColors.yellow.withOpacity(0.4))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TRANSLATED TO YOUR LANGUAGE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BeeColors.yellow)),
                      const SizedBox(height: 6),
                      Text(msg.translatedText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: BeeColors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BeeColors.charcoal,
      appBar: AppBar(
        backgroundColor: BeeColors.charcoal,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: BeeColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: BeeColors.charcoalCard,
                  ),
                  child: Center(child: Text(widget.otherAvatar, style: const TextStyle(fontSize: 20))),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: BeeColors.onlineGreen, shape: BoxShape.circle, border: Border.all(color: BeeColors.charcoal, width: 2)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: BeeColors.white)),
                  Text(widget.otherLang, style: const TextStyle(fontSize: 11, color: BeeColors.yellow, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Privacy Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            color: BeeColors.charcoalSurface,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_clock_outlined, size: 13, color: BeeColors.yellow),
                SizedBox(width: 6),
                Text('30-Day Auto-Clear Active • Dynamic Instant Translation', style: TextStyle(fontSize: 11, color: BeeColors.yellowAccent)),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.otherAvatar, style: const TextStyle(fontSize: 44)),
                        const SizedBox(height: 8),
                        Text('Chat with ${widget.otherName}', style: const TextStyle(fontWeight: FontWeight.w700, color: BeeColors.white)),
                        const SizedBox(height: 4),
                        Text('Send a message in ${widget.currentUser.nativeLanguage.split(' ')[0]}!', style: const TextStyle(color: BeeColors.charcoalMuted, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, index) {
                      final msg = _messages[index];
                      final displayText = msg.isMe ? msg.originalText : (msg.showOriginal ? msg.originalText : msg.translatedText);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: msg.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!msg.isMe) ...[
                              Container(
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.only(right: 6, bottom: 4),
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: BeeColors.charcoalCard),
                                child: Center(child: Text(msg.senderAvatar, style: const TextStyle(fontSize: 14))),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 6, bottom: 4),
                                child: InkWell(
                                  onTap: () => _showTranslationInsight(msg),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: BeeColors.charcoalCard, shape: BoxShape.circle, border: Border.all(color: BeeColors.charcoalBorder)),
                                    child: const Text('👁️', style: TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ),
                            ],
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.74),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: msg.isMe ? BeeColors.yellow : BeeColors.charcoalCard,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft: Radius.circular(msg.isMe ? 18 : 4),
                                    bottomRight: Radius.circular(msg.isMe ? 4 : 18),
                                  ),
                                  border: Border.all(color: msg.isMe ? BeeColors.yellowDark : BeeColors.charcoalBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!msg.isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          msg.showOriginal ? "Original (${msg.senderLang.split(' ')[0]})" : "Translated from ${msg.senderLang.split(' ')[0]}",
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: BeeColors.yellowAccent),
                                        ),
                                      ),
                                    Text(
                                      displayText,
                                      style: TextStyle(fontSize: 15, height: 1.35, color: msg.isMe ? BeeColors.charcoal : BeeColors.white, fontWeight: msg.isMe ? FontWeight.w500 : FontWeight.w400),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(msg.time, style: TextStyle(fontSize: 10, color: msg.isMe ? BeeColors.charcoal.withOpacity(0.7) : BeeColors.charcoalMuted)),
                                        if (msg.isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(Icons.done_all, size: 13, color: BeeColors.charcoal.withOpacity(0.7)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: BeeColors.charcoalSurface, border: Border(top: BorderSide(color: BeeColors.charcoalBorder))),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: BeeColors.charcoal, borderRadius: BorderRadius.circular(24), border: Border.all(color: BeeColors.charcoalBorder)),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: BeeColors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Type in ${widget.currentUser.nativeLanguage.split(' ')[0]}...',
                          hintStyle: const TextStyle(color: BeeColors.charcoalMuted, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: BeeColors.yellow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: BeeColors.yellow.withOpacity(0.35), blurRadius: 12)]),
                      child: const Icon(Icons.send_rounded, color: BeeColors.charcoal, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
