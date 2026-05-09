# 🚀 EduSphere Flutter — Setup & Run Guide

## ✅ Files Created

```
edusphere_flutter/
├── lib/
│   ├── main.dart                    ✅
│   ├── theme/app_theme.dart         ✅
│   ├── models/user_model.dart       ✅
│   ├── screens/
│   │   ├── splash_screen.dart       ✅
│   │   ├── onboarding_screen.dart   ✅
│   │   ├── login_screen.dart        ✅
│   │   ├── main_screen.dart         ✅
│   │   ├── dashboard_screen.dart    ✅
│   │   ├── academics_screen.dart    ✅
│   │   ├── messages_screen.dart     ✅
│   │   └── profile_screen.dart      ✅
│   └── widgets/
│       ├── stat_card.dart           ✅
│       ├── quick_action_button.dart ✅
│       └── notification_item.dart   ✅
├── assets/images/logo.png           ✅
├── pubspec.yaml                     ✅
└── android/                         ✅
```

---

## 📥 Step 1 — Flutter Install Karo

1. https://docs.flutter.dev/get-started/install/windows pe jao
2. Flutter SDK download karo
3. Extract karo `C:\flutter` mein
4. Environment variable mein add karo: `C:\flutter\bin`
5. Terminal mein check karo: `flutter doctor`

---

## 📦 Step 2 — Dependencies Install Karo

```bash
cd edusphere_flutter
flutter pub get
```

---

## ▶️ Step 3 — Run Karo

### Android Phone pe (USB se connect karke):
```bash
flutter run
```

### Android Emulator pe:
```bash
flutter emulators --launch <emulator_id>
flutter run
```

### APK Build karo:
```bash
flutter build apk --release
```
APK milega: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🔐 Login Credentials

| Role | Email | Password |
|------|-------|----------|
| 👨‍🎓 Student | `alex.rivera@edusmart.edu` | `Student@2024` |
| 👨‍🏫 Teacher | `prof.harrison@edusmart.edu` | `Teacher@2024` |

---

## 🎨 App Features

- ✅ Splash Screen (EduSphere logo with animation)
- ✅ Onboarding (3 slides)
- ✅ Login (Student Blue / Teacher Green theme)
- ✅ Auto-fill credentials
- ✅ Dashboard (Stats, Quick Actions, Notifications)
- ✅ Academics (8 modules per role)
- ✅ Messages (Chat list + Chat view)
- ✅ Profile (Edit, Settings, Logout)
- ✅ Logout confirmation dialog
- ✅ Toast notifications
- ✅ Smooth animations
