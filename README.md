# 📟 Textgram

**A minimalist terminal-styled Telegram client built with Flutter and TDLib**

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![TDLib](https://img.shields.io/badge/TDLib-1.8.0-2CA5E0?logo=telegram)](https://core.telegram.org/tdlib)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## ✨ Features

### 🎨 **Retro Terminal Aesthetic**
- Monospace font (JetBrains Mono)
- Green-on-black color scheme
- CRT scanline effects
- ASCII-style UI elements

### 💬 **Core Messaging**
- Send and receive text messages
- Reply to messages
- Edit your own messages
- Delete messages (with revoke)
- Long press for message actions
- No fancy media in case you tired from them

### 📊 **Smart Performance**
- **Debounced UI updates** - 50ms batching reduces redraws by 25x
- **Set-based message storage** - O(1) lookups instead of O(n)
- **Lazy loading** - Messages load in chunks of 50
- **Memory-safe FFI** - Proper pointer management prevents leaks
- **Optimized chat list** - Smart sorting only when needed

### 🔐 **Authentication**
- Phone number + SMS code
- Two-factor authentication (2FA)
- Session persistence

---

## 🚀 Quick Start

### Prerequisites

- Flutter 3.0 or higher
- TDLib compiled library (`libtdjson.so`)
- Linux (primary), Windows/macOS with adjustments

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/textgram.git
cd textgram
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Setup TDLib**

Download or compile TDLib and place `libtdjson.so` in:
```
textgram/
└── tdlib/
    └── libtdjson.so
```

Or update the path in `td_client.dart`:
```dart
tdlib = DynamicLibrary.open('path/to/libtdjson.so');
```

4. **Get Telegram API credentials**

Visit [my.telegram.org](https://my.telegram.org) and create an app to get:
- `api_id`
- `api_hash`

Update them in `td_client.dart`:
```dart
'api_id': YOUR_API_ID,
'api_hash': 'YOUR_API_HASH',
```

5. **Run the app**
```bash
flutter run
```

---

## 📂 Project Structure

```
lib/
├── core/
│   ├── app_controller.dart      # Main app state management
│   ├── td.dart                  # TDLib service (FFI wrapper)
│   └── td_receiver.dart         # Update handler
├── models/
│   └── models.dart              # Data models (Chat, AppState, etc.)
├── pages/
│   ├── auth_screen.dart         # Login flow
│   ├── chat_list_screen.dart   # List of chats
│   ├── chat_screen.dart         # Message view
│   └── profile_screen.dart      # User/channel profile
├── widgets/
│   ├── app_theme.dart           # Terminal color scheme
│   └── widgets.dart             # Reusable UI components
└── main.dart                    # App entry point
```

---

## 🎯 Architecture

### State Management
- **Provider** pattern for reactive UI updates
- **ChangeNotifier** in `AppController`
- Debounced notifications to reduce overhead

### TDLib Integration
```
User Action → AppController → TdLibService (FFI) → TDLib
                                                      ↓
UI Update ← AppController ← TDReceiver ← JSON Response
```

### Key Optimizations

1. **Memory Management**
   - TDLib owns returned string pointers (no manual free)
   - Proper cleanup in `dispose()` methods

2. **Data Structures**
   - `Set<int>` for message ID lookups (O(1))
   - `Map<int, dynamic>` for message content
   - Sorted `List<int>` for UI rendering

3. **Network Efficiency**
   - Batched deletions (N requests → 1)
   - Cached user info
   - Debounced chat list reloads

4. **UI Performance**
   - 50ms debounce on state changes
   - Lazy list rendering with `ListView.builder`
   - Const constructors where possible

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:


## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **TDLib** - Telegram Database Library by Telegram
- **JetBrains Mono** - Font by JetBrains
- **Flutter Community** - For amazing packages and support


<p align="center">
  <sub>If you found this project useful, consider giving it a ⭐!</sub>
</p>
