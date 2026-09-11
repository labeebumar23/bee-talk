import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Global Navigator Key for Notification Deep Linking & In-App Alerts
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ==========================================
// 🔔 GLOBAL NOTIFICATION SERVICE
// ==========================================
class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String? activeRoomId;
  AppUser? currentUser;

  final Map<String, StreamSubscription<DatabaseEvent>> _roomSubs = {};
  StreamSubscription<DatabaseEvent>? _chatsSub;

  static const String channelId = 'bee_talk_messages';
  static const String channelName = 'Bee Talk Messages';
  static const String channelDescription = 'Notifications for new chat messages in Bee Talk';

  Future<void> initialize() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _handleNotificationClick(data);
          } catch (e) {
            debugPrint('Error handling notification click: $e');
          }
        }
      },
    );

    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
        ),
      );
    }

    _isInitialized = true;
    debugPrint('🐝 NotificationService initialized successfully');
  }

  Future<void> requestPermissions() async {
    try {
      await Permission.notification.request();
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    if (currentUser == null) return;
    final roomId = data['roomId']?.toString() ?? '';
    final otherUid = data['senderId']?.toString() ?? '';
    final otherName = data['senderName']?.toString() ?? 'Bee User';
    final otherAvatar = data['senderAvatar']?.toString() ?? '🐝';
    final otherLang = data['senderLang']?.toString() ?? 'English';

    if (roomId.isNotEmpty && activeRoomId != roomId) {
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            roomId: roomId,
            currentUser: currentUser!,
            otherUid: otherUid,
            otherName: otherName,
            otherAvatar: otherAvatar,
            otherLang: otherLang,
          ),
        ),
      );
    }
  }

  Future<void> showLocalNotification({
    required String roomId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String messageText,
    required String senderLang,
  }) async {
    if (activeRoomId == roomId) return;

    final int notificationId = roomId.hashCode.abs() % 100000;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        messageText,
        htmlFormatBigText: false,
        contentTitle: '$senderAvatar $senderName',
        htmlFormatContentTitle: false,
        summaryText: 'Bee Talk',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'roomId': roomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'senderLang': senderLang,
    });

    try {
      await _notificationsPlugin.show(
        notificationId,
        '$senderAvatar $senderName',
        messageText,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  void startListening(AppUser user, {Function(String roomId, String name, String avatar, String text)? onInAppBanner}) {
    currentUser = user;
    final db = FirebaseDatabase.instance.ref();
    final userChatsRef = db.child('user_chats').child(user.uid);
    final appStartTime = DateTime.now().millisecondsSinceEpoch - 500;

    _chatsSub?.cancel();
    _chatsSub = userChatsRef.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      for (final key in data.keys) {
        final roomId = key.toString();
        if (_roomSubs.containsKey(roomId)) continue;

        final query = db.child('messages').child(roomId).orderByChild('timestamp').limitToLast(1);
        final sub = query.onChildAdded.listen((msgEvent) {
          if (!msgEvent.snapshot.exists || msgEvent.snapshot.value == null) return;
          final msg = Map<dynamic, dynamic>.from(msgEvent.snapshot.value as Map);

          final senderId = (msg['senderId'] ?? '').toString();
          final timestamp = (msg['timestamp'] is int) ? msg['timestamp'] as int : DateTime.now().millisecondsSinceEpoch;

          if (senderId.isNotEmpty && senderId != user.uid && timestamp > appStartTime) {
            final senderName = (msg['senderName'] ?? 'Bee User').toString();
            final senderAvatar = (msg['senderAvatar'] ?? '🐝').toString();
            final text = (msg['text'] ?? msg['originalText'] ?? '').toString();
            final senderLang = (msg['senderLang'] ?? 'English').toString();

            // Automatically mark delivered
            final msgKey = msgEvent.snapshot.key;
            if (msgKey != null && (msg['status'] == null || msg['status'] == 'sent')) {
              db.child('messages').child(roomId).child(msgKey).update({'status': 'delivered'});
            }

            if (activeRoomId != roomId) {
              showLocalNotification(
                roomId: roomId,
                senderId: senderId,
                senderName: senderName,
                senderAvatar: senderAvatar,
                messageText: text,
                senderLang: senderLang,
              );
              onInAppBanner?.call(roomId, senderName, senderAvatar, text);
            }
          }
        });

        _roomSubs[roomId] = sub;
      }
    });
  }

  void stopListening() {
    _chatsSub?.cancel();
    for (final sub in _roomSubs.values) {
      sub.cancel();
    }
    _roomSubs.clear();
  }
}

// ==========================================
// 🚀 APP ENTRY & SESSION INITIALIZATION
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

  // Initialize notification engine
  await NotificationService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();
  final isOnboarded = prefs.getBool('pref_is_onboarded') ?? false;
  final uid = prefs.getString('pref_user_uid');
  final displayName = prefs.getString('pref_display_name');
  final nativeLanguage = prefs.getString('pref_native_language');
  final avatar = prefs.getString('pref_avatar') ?? '🐝';
  final inviteCode = prefs.getString('pref_invite_code') ?? '';

  AppUser? savedUser;
  if (isOnboarded && uid != null && displayName != null && displayName.isNotEmpty && nativeLanguage != null) {
    savedUser = AppUser(
      uid: uid,
      displayName: displayName,
      nativeLanguage: nativeLanguage,
      avatar: avatar,
      inviteCode: inviteCode,
    );
  }

  runApp(BeeTalkApp(initialUser: savedUser));
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
  static const Color seenBlue = Color(0xFF0284C7); // WhatsApp Blue / Electric Sky
}

// ==========================================
// 🌍 SUPPORTED LANGUAGES
// ==========================================
class BeeLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const BeeLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  String get label => '$name ($nativeName) $flag';
}

class BeeLanguages {
  static const List<BeeLanguage> all = [
    BeeLanguage(code: 'en', name: 'English', nativeName: 'English', flag: '🇺🇸'),
    BeeLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flag: '🇮🇩'),
    BeeLanguage(code: 'ur', name: 'Urdu', nativeName: 'اردو', flag: '🇵🇰'),
    BeeLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flag: '🇹🇷'),
    BeeLanguage(code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
    BeeLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦'),
    BeeLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
    BeeLanguage(code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
    BeeLanguage(code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
    BeeLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
    BeeLanguage(code: 'zh', name: 'Chinese', nativeName: '中文', flag: '🇨🇳'),
    BeeLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский', flag: '🇷🇺'),
    BeeLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português', flag: '🇧🇷'),
    BeeLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano', flag: '🇮🇹'),
    BeeLanguage(code: 'ko', name: 'Korean', nativeName: '한국어', flag: '🇰🇷'),
    BeeLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flag: '🇳🇱'),
    BeeLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski', flag: '🇵🇱'),
    BeeLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', flag: '🇻🇳'),
  ];

  static List<String> get labels => all.map((l) => l.label).toList();

  static BeeLanguage getByCode(String code) {
    return all.firstWhere(
      (l) => l.code.toLowerCase() == code.toLowerCase(),
      orElse: () => all.first,
    );
  }

  static BeeLanguage getByLabel(String label) {
    final clean = label.toLowerCase();
    return all.firstWhere(
      (l) => clean.contains(l.name.toLowerCase()) || clean.contains(l.nativeName.toLowerCase()) || clean.startsWith(l.code),
      orElse: () => all.first,
    );
  }
}

// ==========================================
// 🌐 MEMOIZED REAL-TIME TRANSLATION ENGINE
// ==========================================
class RealtimeTranslator {
  static final Map<String, String> _cache = {};

  static String extractLangCode(String langStr) {
    final clean = langStr.trim().toLowerCase();
    for (final lang in BeeLanguages.all) {
      if (clean.contains(lang.name.toLowerCase()) ||
          clean.contains(lang.nativeName.toLowerCase()) ||
          clean == lang.code ||
          clean.startsWith('${lang.code} ')) {
        return lang.code;
      }
    }
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

    // 1. Primary Engine: Google Translate API
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
      debugPrint('Primary translation error: $e');
    }

    // 2. Fallback Engine: MyMemory API
    try {
      final fallbackUrl = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(trimmed)}&langpair=$src|$tgt',
      );
      final response = await http.get(fallbackUrl).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final translated = data['responseData']?['translatedText']?.toString();
        if (translated != null && translated.isNotEmpty && !translated.startsWith('MYMEMORY WARNING')) {
          _cache[cacheKey] = translated;
          return translated;
        }
      }
    } catch (e) {
      debugPrint('Fallback translation error: $e');
    }

    return trimmed;
  }
}

// ==========================================
// 📱 MAIN APPLICATION ENTRY WIDGET
// ==========================================
class BeeTalkApp extends StatelessWidget {
  final AppUser? initialUser;

  const BeeTalkApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
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
      home: initialUser != null ? InboxScreen(currentUser: initialUser!) : const OnboardingScreen(),
    );
  }
}

// ==========================================
// 📦 USER & CHAT DATA MODELS
// ==========================================
class AppUser {
  String uid;
  String displayName;
  String nativeLanguage;
  String avatar;
  String inviteCode;

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
  final String lastMessageSenderId;
  final String lastMessageStatus;

  ChatRoomItem({
    required this.roomId,
    required this.otherUid,
    required this.otherName,
    required this.otherAvatar,
    required this.otherLang,
    required this.lastMessage,
    required this.lastTimestamp,
    this.lastMessageSenderId = '',
    this.lastMessageStatus = 'sent',
  });

  Map<String, dynamic> toMap() => {
    'roomId': roomId,
    'otherUid': otherUid,
    'otherName': otherName,
    'otherAvatar': otherAvatar,
    'otherLang': otherLang,
    'lastMessage': lastMessage,
    'lastTimestamp': lastTimestamp,
    'lastMessageSenderId': lastMessageSenderId,
    'lastMessageStatus': lastMessageStatus,
  };

  factory ChatRoomItem.fromMap(Map<String, dynamic> map) => ChatRoomItem(
    roomId: (map['roomId'] ?? '').toString(),
    otherUid: (map['otherUid'] ?? '').toString(),
    otherName: (map['otherName'] ?? 'Bee User').toString(),
    otherAvatar: (map['otherAvatar'] ?? '🐝').toString(),
    otherLang: (map['otherLang'] ?? 'English').toString(),
    lastMessage: (map['lastMessage'] ?? '').toString(),
    lastTimestamp: (map['lastTimestamp'] is int) ? map['lastTimestamp'] : 0,
    lastMessageSenderId: (map['lastMessageSenderId'] ?? '').toString(),
    lastMessageStatus: (map['lastMessageStatus'] ?? 'sent').toString(),
  );
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
  String status; // 'sent', 'delivered', 'seen'
  int? seenAt;
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
    this.status = 'sent',
    this.seenAt,
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
  final TextEditingController _nameController = TextEditingController();
  String _selectedLanguage = 'English (English) 🇺🇸';
  int _avatarIndex = 0;
  String? _error;
  bool _isLoading = false;

  final List<String> _languages = BeeLanguages.labels;
  final List<String> _avatars = ['🐝', '🍯', '👑', '⚡', '🌻', '🚀', '✨', '🔥'];

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_user_uid', uid);
      await prefs.setString('pref_display_name', name);
      await prefs.setString('pref_native_language', _selectedLanguage);
      await prefs.setString('pref_avatar', avatar);
      await prefs.setString('pref_invite_code', inviteCode);
      await prefs.setBool('pref_is_onboarded', true);

      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('users').child(uid).set(currentUser.toMap());

      await dbRef.child('invites').child(inviteCode).set({
        'code': inviteCode,
        'creatorUid': uid,
        'creatorName': name,
        'creatorAvatar': avatar,
        'creatorLang': _selectedLanguage,
        'createdAt': ServerValue.timestamp,
      });

      // Presence
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

      // Request notification permission
      await NotificationService.instance.requestPermissions();

      if (!mounted) return;

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
                    'Tap avatar to change icon',
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
                            Text('Get Started', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                    Text('Private 1-on-1 • Real-Time Dynamic Translation', style: TextStyle(fontSize: 12, color: BeeColors.charcoalMuted)),
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
// 📥 SCREEN 2: INBOX & OPTIMIZED CHAT LIST (HOME)
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
    _loadCachedRooms();
    _listenToUserChats();
    NotificationService.instance.requestPermissions();
    NotificationService.instance.startListening(
      widget.currentUser,
      onInAppBanner: (roomId, name, avatar, text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: BeeColors.charcoalSurface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: BeeColors.yellow, width: 1.5),
            ),
            content: Row(
              children: [
                Text(avatar, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: BeeColors.white)),
                      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BeeColors.charcoalMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      },
    );
  }

  Future<void> _loadCachedRooms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('cached_rooms_${widget.currentUser.uid}');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cachedStr);
        final rooms = list.map((e) => ChatRoomItem.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted && rooms.isNotEmpty) {
          setState(() {
            _chatRooms.clear();
            _chatRooms.addAll(rooms);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached rooms: $e');
    }
  }

  Future<void> _saveCachedRooms(List<ChatRoomItem> rooms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = rooms.map((r) => r.toMap()).toList();
      await prefs.setString('cached_rooms_${widget.currentUser.uid}', jsonEncode(list));
    } catch (e) {
      debugPrint('Error saving cached rooms: $e');
    }
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
        _saveCachedRooms([]);
        return;
      }

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final roomIds = data.keys.map((k) => k.toString()).toList();

      // Parallel async fetching for instant loading
      final roomSnaps = await Future.wait(
        roomIds.map((roomId) => dbRef.child('chat_rooms').child(roomId).get()),
      );

      final List<ChatRoomItem> rooms = [];

      for (int i = 0; i < roomSnaps.length; i++) {
        final roomSnap = roomSnaps[i];
        final roomId = roomIds[i];

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
          final lastSenderId = (roomData['lastMessageSenderId'] ?? '').toString();
          final lastStatus = (roomData['lastMessageStatus'] ?? 'sent').toString();

          rooms.add(ChatRoomItem(
            roomId: roomId,
            otherUid: otherUid,
            otherName: otherName,
            otherAvatar: otherAvatar,
            otherLang: otherLang,
            lastMessage: lastMessage,
            lastTimestamp: lastTimestamp,
            lastMessageSenderId: lastSenderId,
            lastMessageStatus: lastStatus,
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
        _saveCachedRooms(rooms);
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
                          'lastMessageStatus': 'sent',
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

  void _openSettings() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(currentUser: widget.currentUser),
      ),
    );

    if (updated == true && mounted) {
      setState(() {});
    }
  }

  Widget _buildStatusMiniIcon(ChatRoomItem room) {
    if (room.lastMessageSenderId != widget.currentUser.uid) {
      return const SizedBox.shrink();
    }

    if (room.lastMessageStatus == 'seen') {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(Icons.done_all_rounded, size: 14, color: BeeColors.seenBlue),
      );
    } else if (room.lastMessageStatus == 'delivered') {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.done_all_rounded, size: 14, color: BeeColors.charcoalMuted.withOpacity(0.8)),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Icon(Icons.done_rounded, size: 14, color: BeeColors.charcoalMuted.withOpacity(0.8)),
      );
    }
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
        title: GestureDetector(
          onTap: _openSettings,
          child: Row(
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
                  Text(
                    "${widget.currentUser.nativeLanguage.split(' ')[0]} • Code: ${widget.currentUser.inviteCode}",
                    style: const TextStyle(fontSize: 11, color: BeeColors.yellow, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: BeeColors.white),
            tooltip: 'Settings & Profile',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: BeeColors.yellow),
            tooltip: 'Share Invite Code',
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

          // Privacy & Features Banner
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
                    '🔒 Real-Time Read Receipts • Push Alerts • 30-Day Auto Retention',
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
                                'Share your invite code (${widget.currentUser.inviteCode}) or tap "+ New Chat" to start a conversation in any language!',
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
                              child: Row(
                                children: [
                                  _buildStatusMiniIcon(room),
                                  Expanded(
                                    child: Text(
                                      room.lastMessage,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: BeeColors.charcoalMuted),
                                    ),
                                  ),
                                ],
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
// ⚙️ SCREEN 4: SETTINGS & PROFILE EDITING
// ==========================================
class SettingsScreen extends StatefulWidget {
  final AppUser currentUser;

  const SettingsScreen({super.key, required this.currentUser});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late String _selectedLanguage;
  late String _avatar;
  bool _isSaving = false;

  final List<String> _avatars = ['🐝', '🍯', '👑', '⚡', '🌻', '🚀', '✨', '🔥'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.displayName);
    _selectedLanguage = widget.currentUser.nativeLanguage;
    _avatar = widget.currentUser.avatar;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name cannot be empty'), backgroundColor: BeeColors.errorRed),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pref_display_name', newName);
      await prefs.setString('pref_native_language', _selectedLanguage);
      await prefs.setString('pref_avatar', _avatar);

      widget.currentUser.displayName = newName;
      widget.currentUser.nativeLanguage = _selectedLanguage;
      widget.currentUser.avatar = _avatar;

      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('users').child(widget.currentUser.uid).update({
        'displayName': newName,
        'nativeLanguage': _selectedLanguage,
        'avatar': _avatar,
      });

      if (widget.currentUser.inviteCode.isNotEmpty) {
        await dbRef.child('invites').child(widget.currentUser.inviteCode).update({
          'creatorName': newName,
          'creatorLang': _selectedLanguage,
          'creatorAvatar': _avatar,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully! 🐝'), backgroundColor: BeeColors.yellow),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e'), backgroundColor: BeeColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BeeColors.charcoalSurface,
        title: const Text('Reset Profile?', style: TextStyle(color: BeeColors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will clear your local session and return you to onboarding.',
          style: TextStyle(color: BeeColors.charcoalMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: BeeColors.charcoalMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: BeeColors.errorRed, foregroundColor: BeeColors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      NotificationService.instance.stopListening();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    }
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
        title: const Text('Settings & Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: BeeColors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: BeeColors.yellow))
                  : const Text('Save', style: TextStyle(color: BeeColors.yellow, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Avatar Selector
            Center(
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [BeeColors.yellowAccent, BeeColors.yellowDark]),
                      border: Border.all(color: BeeColors.charcoalBorder, width: 3),
                    ),
                    child: Center(child: Text(_avatar, style: const TextStyle(fontSize: 42))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Choose Avatar', style: TextStyle(fontSize: 13, color: BeeColors.charcoalMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: _avatars.map((av) {
                      final isSelected = av == _avatar;
                      return GestureDetector(
                        onTap: () => setState(() => _avatar = av),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? BeeColors.yellow : BeeColors.charcoalCard,
                            border: Border.all(color: isSelected ? BeeColors.yellowDark : BeeColors.charcoalBorder, width: 2),
                          ),
                          child: Text(av, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Profile Fields
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: BeeColors.charcoalSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BeeColors.charcoalBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Display Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BeeColors.white)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: BeeColors.white, fontSize: 16),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, color: BeeColors.yellow),
                      filled: true,
                      fillColor: BeeColors.charcoal,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BeeColors.charcoalBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: BeeColors.yellow, width: 2)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Preferred Language', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BeeColors.white)),
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
                        items: BeeLanguages.labels.map((String lang) {
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
            const SizedBox(height: 20),

            // Notification Permissions test
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BeeColors.charcoalSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BeeColors.charcoalBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, color: BeeColors.yellow, size: 22),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Push Notifications', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: BeeColors.white)),
                          Text('Receive alerts for new messages', style: TextStyle(fontSize: 11, color: BeeColors.charcoalMuted)),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      await NotificationService.instance.requestPermissions();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notifications active! 🔔'), backgroundColor: BeeColors.yellow),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: BeeColors.charcoalCard, foregroundColor: BeeColors.yellow),
                    child: const Text('Allow'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Invite Code Info
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: BeeColors.charcoalSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BeeColors.charcoalBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Invite Code', style: TextStyle(fontSize: 12, color: BeeColors.charcoalMuted)),
                      const SizedBox(height: 4),
                      Text(widget.currentUser.inviteCode, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: BeeColors.yellow, letterSpacing: 1.5)),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: widget.currentUser.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Code ${widget.currentUser.inviteCode} copied!'), backgroundColor: BeeColors.yellow),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: BeeColors.charcoalCard, foregroundColor: BeeColors.white),
                    icon: const Icon(Icons.copy, size: 16, color: BeeColors.yellow),
                    label: const Text('Copy'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Save Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: BeeColors.yellow,
                foregroundColor: BeeColors.charcoal,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: BeeColors.charcoal))
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),

            // Reset Profile / Sign Out
            OutlinedButton.icon(
              onPressed: _handleLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: BeeColors.errorRed,
                side: const BorderSide(color: BeeColors.charcoalBorder),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Reset Profile / Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 💬 SCREEN 3: 1-ON-1 CHAT ROOM (PAGINATED & SEEN RECEIPT)
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

  bool _isLoadingMore = false;
  bool _hasMoreHistorical = true;
  static const int pageSize = 30;
  static const int monthlyRetentionMs = 30 * 24 * 60 * 60 * 1000;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.activeRoomId = widget.roomId;
    _initChat();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 60 &&
        !_isLoadingMore &&
        _hasMoreHistorical &&
        _messages.isNotEmpty) {
      _loadEarlierMessages();
    }
  }

  void _initChat() {
    final db = FirebaseDatabase.instance;
    _messagesRef = db.ref('messages').child(widget.roomId);

    _markMessagesAsSeen();

    final cutoffTimestamp = DateTime.now().millisecondsSinceEpoch - monthlyRetentionMs;

    // Optimized initial load with limitToLast
    _messagesSubscription = _messagesRef
        .orderByChild('timestamp')
        .limitToLast(pageSize)
        .onValue
        .listen((event) async {
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
            final originalText = (val['text'] ?? val['originalText'] ?? '').toString();
            final senderLang = (val['senderLang'] ?? widget.otherLang).toString();
            final status = (val['status'] ?? 'sent').toString();
            final seenAt = (val['seenAt'] is int) ? val['seenAt'] as int : null;

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
              status: status,
              seenAt: seenAt,
            ));
          } else {
            expiredIds.add(key);
          }
        }
      }

      for (final id in expiredIds) {
        _messagesRef.child(id).remove();
      }

      activeMessages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (mounted) {
        // Mark any incoming message as seen immediately
        _markMessagesAsSeen();

        setState(() {
          // Merge with any existing earlier loaded messages
          final existingIds = activeMessages.map((m) => m.id).toSet();
          final historicalKept = _messages.where((m) => !existingIds.contains(m.id)).toList();
          _messages.clear();
          _messages.addAll(historicalKept);
          _messages.addAll(activeMessages);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
        _scrollToBottom();
      }
    });
  }

  Future<void> _loadEarlierMessages() async {
    if (_isLoadingMore || !_hasMoreHistorical || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final oldestTimestamp = _messages.first.timestamp;
      final snap = await _messagesRef
          .orderByChild('timestamp')
          .endBefore(oldestTimestamp)
          .limitToLast(25)
          .get();

      if (!snap.exists || snap.value == null || snap.value is! Map) {
        if (mounted) setState(() => _hasMoreHistorical = false);
        return;
      }

      final data = snap.value as Map;
      final List<ChatMessage> earlier = [];

      for (final entry in data.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is Map) {
          final timestamp = (val['timestamp'] is int) ? val['timestamp'] as int : 0;
          final senderId = (val['senderId'] ?? '').toString();
          final isMe = senderId == widget.currentUser.uid;
          final originalText = (val['text'] ?? val['originalText'] ?? '').toString();
          final senderLang = (val['senderLang'] ?? widget.otherLang).toString();
          final status = (val['status'] ?? 'sent').toString();
          final seenAt = (val['seenAt'] is int) ? val['seenAt'] as int : null;

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

          earlier.add(ChatMessage(
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
            status: status,
            seenAt: seenAt,
          ));
        }
      }

      if (earlier.isEmpty) {
        if (mounted) setState(() => _hasMoreHistorical = false);
      } else {
        earlier.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (mounted) {
          setState(() {
            final existingIds = _messages.map((m) => m.id).toSet();
            final uniqueEarlier = earlier.where((m) => !existingIds.contains(m.id)).toList();
            _messages.insertAll(0, uniqueEarlier);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading earlier messages: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markMessagesAsSeen() async {
    try {
      final snap = await _messagesRef.orderByChild('timestamp').limitToLast(25).get();
      if (!snap.exists || snap.value == null || snap.value is! Map) return;

      final data = snap.value as Map;
      final Map<String, Object?> updates = {};
      final now = DateTime.now().millisecondsSinceEpoch;

      data.forEach((k, v) {
        if (v is Map) {
          final senderId = (v['senderId'] ?? '').toString();
          final status = (v['status'] ?? 'sent').toString();
          if (senderId.isNotEmpty && senderId != widget.currentUser.uid && status != 'seen') {
            updates['$k/status'] = 'seen';
            updates['$k/seenAt'] = now;
          }
        }
      });

      if (updates.isNotEmpty) {
        await _messagesRef.update(updates);
        // Also update room's last message status if from other user
        final dbRef = FirebaseDatabase.instance.ref();
        await dbRef.child('chat_rooms').child(widget.roomId).update({'lastMessageStatus': 'seen'});
      }
    } catch (e) {
      debugPrint('Error marking seen: $e');
    }
  }

  @override
  void dispose() {
    NotificationService.instance.activeRoomId = null;
    _messagesSubscription?.cancel();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final newMsgRef = _messagesRef.push();
    final newId = newMsgRef.key ?? timestamp.toString();

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    final formattedTime = "$hour:$minute $period";

    // Optimistic UI update for instant feedback
    final optimisticMsg = ChatMessage(
      id: newId,
      senderId: widget.currentUser.uid,
      sender: widget.currentUser.displayName,
      senderAvatar: widget.currentUser.avatar,
      originalText: text,
      translatedText: text,
      senderLang: widget.currentUser.nativeLanguage,
      time: formattedTime,
      timestamp: timestamp,
      isMe: true,
      status: 'sent',
    );

    setState(() {
      _messages.add(optimisticMsg);
    });
    _scrollToBottom();

    try {
      await newMsgRef.set({
        'senderId': widget.currentUser.uid,
        'senderName': widget.currentUser.displayName,
        'senderAvatar': widget.currentUser.avatar,
        'senderLang': widget.currentUser.nativeLanguage,
        'text': text,
        'timestamp': timestamp,
        'status': 'sent',
      });

      final dbRef = FirebaseDatabase.instance.ref();
      await dbRef.child('chat_rooms').child(widget.roomId).update({
        'lastMessageText': text,
        'lastMessageSenderId': widget.currentUser.uid,
        'lastMessageTimestamp': timestamp,
        'lastMessageStatus': 'sent',
      });
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

  Widget _buildReadReceiptIcon(ChatMessage msg) {
    if (!msg.isMe) return const SizedBox.shrink();

    switch (msg.status) {
      case 'seen':
        return const Tooltip(
          message: 'Seen',
          child: Icon(
            Icons.done_all_rounded,
            size: 14,
            color: BeeColors.seenBlue, // WhatsApp Blue Double Ticks
          ),
        );
      case 'delivered':
        return Tooltip(
          message: 'Delivered',
          child: Icon(
            Icons.done_all_rounded,
            size: 14,
            color: BeeColors.charcoal.withOpacity(0.65),
          ),
        );
      case 'sent':
      default:
        return Tooltip(
          message: 'Sent',
          child: Icon(
            Icons.done_rounded,
            size: 14,
            color: BeeColors.charcoal.withOpacity(0.65),
          ),
        );
    }
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
                Text('Instant Translation Active • Read Receipts Enabled', style: TextStyle(fontSize: 11, color: BeeColors.yellowAccent)),
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
                    itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (ctx, index) {
                      if (_isLoadingMore && index == 0) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: BeeColors.yellow),
                            ),
                          ),
                        );
                      }

                      final actualIndex = _isLoadingMore ? index - 1 : index;
                      final msg = _messages[actualIndex];
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
                                          _buildReadReceiptIcon(msg),
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
