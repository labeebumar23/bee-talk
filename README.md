# 🐝 Bee Talk - Modern, Minimal Mobile Chat Application

**Bee Talk** is a modern, minimal, and creator-focused Android/iOS mobile chat application designed for effortless cross-language communication.

---

## 🎨 App Theme & Aesthetics

- **Golden Yellow** (`#FFB800` / `#FFC107`)
- **Deep Obsidian Charcoal** (`#0F0F12` / `#18181D`)
- **Clean White** (`#FFFFFF` / `#F8FAFC`)

---

## 🚀 Core Tech Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Frontend** | **Flutter** | Native performance, fluid animations, custom Bumblebee design system |
| **Backend** | **Firebase** | Anonymous Authentication (Zero-friction) & Realtime Database |
| **Translation** | **Google ML Kit** | On-Device local translation (Offline, zero latency, zero cloud API limits) |
| **State Management**| **Provider** | Reactive, clean architecture |

---

## 🔑 Key Features

### 1. Frictionless Onboarding (No Phone / Email Required)
- Zero passwords, zero phone numbers, zero spam.
- Enter **Display Name** + Pick **Native Language** from 50+ supported languages.
- Firebase Anonymous Authentication assigns a unique silent UID stored locally.

### 2. 100% Invite-Only Privacy
- No public user search or searchable directory.
- Generate a unique short code (e.g. `BT-492X`) or invite link.
- Enter friend's code on the home screen to establish a secure 1-on-1 chat room.

### 3. The Language Magic (Real-Time Auto-Translation)
- User A writes in **Urdu** (🇵🇰) -> User B receives it instantly in **Turkish** (🇹🇷).
- All translation runs locally on-device using Google ML Kit.
- Tap the **Eye (👁️)** icon on any message bubble to reveal the original untranslated text and language details.

---

## 📁 Project Architecture

```
lib/
├── firebase_options.dart               # Firebase connection configuration
├── main.dart                          # App entry point, MultiProvider & Theme
├── core/
│   ├── constants/app_constants.dart   # Supported languages, DB paths, configs
│   ├── models/
│   │   ├── chat_room_model.dart       # 1-on-1 chat room & participant models
│   │   ├── message_model.dart         # Message model with translation & eye state
│   │   └── user_model.dart            # User profile data model
│   ├── theme/app_theme.dart           # Bumblebee color palette & typography
│   └── utils/
│       ├── avatar_generator.dart      # Procedural Bee avatar generator
│       └── code_generator.dart        # BT-XXXX invite code generator
├── providers/
│   ├── auth_provider.dart             # Silent auth, profile & language updates
│   ├── chat_list_provider.dart        # Real-time active chat rooms & code joining
│   └── chat_provider.dart             # Real-time messages, ML Kit translation & eye toggles
├── services/
│   ├── auth_service.dart              # Firebase Anonymous Auth
│   ├── database_service.dart          # Firebase Realtime Database CRUD & streams
│   ├── local_storage_service.dart     # SharedPreferences offline caching
│   └── translation_service.dart       # Google ML Kit On-Device Translator manager
└── views/
    ├── chat/
    │   ├── chat_screen.dart           # Modern chat room screen
    │   └── widgets/
    │       ├── chat_input_bar.dart    # Creator input bar with language pill
    │       └── message_bubble.dart    # Yellow sender / Charcoal receiver bubbles
    ├── home/home_screen.dart          # Dashboard with active chats & invite actions
    ├── onboarding/onboarding_screen.dart # Frictionless Name + Language setup
    ├── splash/splash_screen.dart      # Animated Bee branding & auto routing
    └── widgets/
        ├── bee_avatar.dart            # Glowing geometric Bee avatar
        ├── invite_code_sheet.dart     # Shareable invite modal
        ├── join_code_sheet.dart       # Enter friend code sheet
        ├── language_picker_sheet.dart # 50+ language searchable bottom sheet
        └── translation_peek_dialog.dart # 👁️ Eye-peek dual language comparison modal
```

---

## 🛠️ How to Run

1. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

2. **Add Your Firebase Project (`google-services.json`)**:
   - Place your `google-services.json` in `android/app/google-services.json`
   - Enable **Anonymous Authentication** and **Realtime Database** in your Firebase Console.

3. **Run on Android device / emulator**:
   ```bash
   flutter run
   ```
