# EduSphere Flutter App

Complete Flutter/Dart conversion of the EduSphere Smart School ERP React app.

## 🚀 Setup Instructions

### 1. Install Flutter SDK
Download from: https://docs.flutter.dev/get-started/install

### 2. Install Dependencies
```bash
cd edusphere_flutter
flutter pub get
```

### 3. Add Logo Image
Copy `icon-source.png` to `assets/images/logo.png`

### 4. Run the App
```bash
# Android
flutter run

# iOS
flutter run

# Web
flutter run -d chrome

# Build APK
flutter build apk --release
```

## 📁 Project Structure

```
edusphere_flutter/
├── lib/
│   ├── main.dart                    ✅ Created
│   ├── theme/
│   │   └── app_theme.dart           ✅ Created
│   ├── models/
│   │   └── user_model.dart          ✅ Created
│   ├── screens/
│   │   ├── splash_screen.dart       ✅ Created
│   │   ├── onboarding_screen.dart   ✅ Created
│   │   ├── login_screen.dart        ✅ Created
│   │   ├── main_screen.dart         ⚠️  TODO
│   │   ├── dashboard_screen.dart    ⚠️  TODO
│   │   ├── academics_screen.dart    ⚠️  TODO
│   │   ├── messages_screen.dart     ⚠️  TODO
│   │   └── profile_screen.dart      ⚠️  TODO
│   └── widgets/
│       ├── stat_card.dart           ⚠️  TODO
│       ├── quick_action_button.dart ⚠️  TODO
│       └── notification_item.dart   ⚠️  TODO
├── assets/
│   └── images/
│       └── logo.png                 ⚠️  TODO (copy icon-source.png here)
├── pubspec.yaml                     ✅ Created
└── README.md                        ✅ This file
```

## ✅ Completed Features

- ✅ Splash Screen with logo animation
- ✅ Onboarding (3 slides with page indicator)
- ✅ Login Screen with role selection (Student/Teacher)
- ✅ Auto-fill credentials
- ✅ Theme system (Blue for Student, Green for Teacher)
- ✅ Form validation
- ✅ Smooth animations

## ⚠️ Remaining Work

### Main Screen (Bottom Navigation)
Create `lib/screens/main_screen.dart`:
- Bottom navigation bar (Home, Academics, Messages, Profile)
- Tab switching logic
- Role-based theme

### Dashboard Screen
Create `lib/screens/dashboard_screen.dart`:
- Greeting header with avatar
- Stats cards (Attendance %, Pending Tasks, etc.)
- Quick action buttons grid
- Recent notifications list
- Calendar widget

### Academics Screen
Create `lib/screens/academics_screen.dart`:
- Module cards (Timetable, Assignments, Results, etc.)
- Progress indicators
- Navigation to sub-screens

### Messages Screen
Create `lib/screens/messages_screen.dart`:
- Chat list
- Search bar
- Unread indicators
- Chat detail view

### Profile Screen
Create `lib/screens/profile_screen.dart`:
- User info card
- Settings menu
- Logout confirmation dialog

### Widgets
Create reusable widgets in `lib/widgets/`:
- `stat_card.dart` - Dashboard stat cards
- `quick_action_button.dart` - Action buttons
- `notification_item.dart` - Notification list items
- `module_card.dart` - Academic module cards

## 🎨 Design System

### Colors
- **Student Theme**: `#1A6FDB` (Blue)
- **Teacher Theme**: `#1B6E35` (Green)
- **Background**: `#F8FAFC`
- **Card**: `#FFFFFF`
- **Text Dark**: `#1E293B`

### Typography
- Font: **Inter** (via Google Fonts)
- Weights: 400, 500, 600, 700, 800, 900

### Border Radius
- Cards: 20px
- Buttons: 16px
- Small elements: 12px

## 🔐 Login Credentials

### Student
- Email: `alex.rivera@edusmart.edu`
- Password: `Student@2024`

### Teacher
- Email: `prof.harrison@edusmart.edu`
- Password: `Teacher@2024`

## 📱 Build APK

```bash
# Debug APK
flutter build apk

# Release APK (optimized)
flutter build apk --release

# Split APKs by ABI (smaller size)
flutter build apk --split-per-abi
```

APK location: `build/app/outputs/flutter-apk/app-release.apk`

## 🔧 Troubleshooting

### "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

### "SDK version error"
Update `android/app/build.gradle`:
```gradle
minSdkVersion 21
targetSdkVersion 33
```

### "Assets not found"
Ensure `pubspec.yaml` has:
```yaml
flutter:
  assets:
    - assets/images/
```

## 📦 Dependencies Used

- `google_fonts` - Inter font family
- `fl_chart` - Charts for analytics
- `percent_indicator` - Circular progress indicators
- `animate_do` - Pre-built animations
- `shared_preferences` - Local storage
- `intl` - Date formatting

## 🚀 Next Steps

1. Copy `icon-source.png` to `assets/images/logo.png`
2. Run `flutter pub get`
3. Create remaining screens (main_screen.dart, dashboard_screen.dart, etc.)
4. Test on Android/iOS
5. Build release APK

---

**Note:** This is a partial conversion. The core navigation flow (Splash → Onboarding → Login) is complete. Dashboard and other screens need to be implemented following the same pattern.
