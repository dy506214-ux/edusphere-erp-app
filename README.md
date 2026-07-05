# EduSphere Mobile ERP App 🚀

Welcome to **EduSphere Mobile**, the complete cross-platform mobile client for the **EduSphere Smart School ERP** ecosystem. This application is built using **Flutter and Dart**, delivering a premium native experience for both students and teachers. It connects in real-time to the production EduSphere backend server.

---

## 🎨 Premium UX & Architecture

* **Vibrant Styling**: Modern typography using Google Fonts (Outfit, Inter) and custom HSL-tailored color palettes.
* **Role-Based Branding**: 
  * **Student Panel**: Premium Deep Blue and Gold theme elements.
  * **Teacher Panel**: Premium Dark Blue, Indigo, and Slate theme elements.
* **Responsive Layouts**: Designed to be completely responsive across a variety of screen viewports—ranging from small-sized phones to tablets—under both portrait and landscape orientations, protecting against `RenderFlex` and pixel overflows.
* **Global Reactive State Management**: Leverages a centralized `AppStateNotifier` (with reactive value listeners) to synchronize state updates instantly across unrelated UI layers (e.g. updating profile pictures in bottom navigation bars, side drawer headers, and large circular profile card avatars simultaneously).

---

## 📱 Feature Modules

### 👩‍🏫 Teacher Panel
1. **Interactive Dashboard**: Quick statistics summary for assignments, lessons, student directories, class rosters, and live attendance metrics.
2. **Student Directory & Detail View**: Browse and filter the list of school students, view their detailed personal records, academic status, fees ledger, and timetables.
3. **Attendance Scanner**: Integrated live camera scanning interface to scan student QR passes for automatic class attendance logging.
4. **Timetable Slot Scheduler**: View and manage weekly teaching hours, slots, and subject distributions.
5. **Assignments Management**: Create, assign, review, and grade smart assignments (with automatic lesson and AI-assisted descriptions).
6. **Self Attendance & Leaves**: Log personal attendance, check monthly records, and submit leave requests.
7. **Profile Management**: Update professional credentials, upload profile photos with native camera/gallery tools, and toggle system notification configurations.

### 👨‍🎓 Student Panel
1. **Personal Dashboard**: Overview of recent grades, notifications, daily classes, and personal announcements.
2. **Academic Directory**: Access study materials, view homework assignments, take online quizzes, inspect exam schedules, and view gradebook results.
3. **Timed Timetable**: Daily and weekly scheduler showcasing classes, subjects, timings, and class teachers.
4. **Fees Ledger & Tracker**: Detailed summary of total due fees, paid invoices, discounts, and real-time fee statement PDF downloads.
5. **Digital ID Pass**: Access a unique personal QR code pass that can be scanned for instant class/campus attendance.
6. **Transport Tracker**: Interactive route maps, assigned bus details, driver contacts, and stop-by-stop listings.
7. **Documents Asset Vault**: A secure vault where students can upload verification documents, certificates, and view uploaded assets.

---

## ⚙️ Technology Stack

* **Framework**: Flutter SDK (3.x) & Dart Language
* **Design Utilities**: Google Fonts, Flutter ScreenUtil for responsive scaling.
* **Networking**: Dio/Http clients, Multipart Request upload payloads, socket services for real-time notifications.
* **State Management**: Reactive State (`ValueNotifier` listeners) mapped in `AppStateNotifier`.
* **Caching**: SharedPreferences local caching alongside unique query-buster timestamps to invalidate network cache cleanly.
* **Backend Connection**: Production REST APIs & WebSockets hosted at:
  * **Base URL**: `https://edusphere-erp-frontend.onrender.com`
  * **API Base**: `https://edusphere-erp-frontend.onrender.com/api/v1`

---

## 🚀 Setup & Installation

### Prerequisites
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (Ensure `flutter doctor` passes).
2. Install Android Studio / VS Code with Dart & Flutter extensions.

### Installation Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/dy506214-ux/edusphere-erp-app.git
   cd edusphere-erp-app
   ```

2. **Retrieve Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Asset Verification**:
   Ensure `assets/images/logo.png` is present (used for app splash and default avatar fallback).

4. **Launch Application**:
   * **Run on Emulators / Connected Devices**:
     ```bash
     flutter run
     ```
   * **Run on Chrome (Web Platform)**:
     ```bash
     flutter run -d chrome
     ```

5. **Build Releases**:
   * **Android APK**:
     ```bash
     flutter build apk --release
     ```
   * **iOS Runner Bundle**:
     ```bash
     flutter build ipa --release
     ```

---

## 📁 Project Directory Structure

```
lib/
├── config/
│   └── api_config.dart          # REST API server endpoint configurations
├── models/
│   ├── notification_model.dart  # Notification models
│   ├── student_model.dart       # Student records
│   └── teacher_model.dart       # Teacher profiles
├── screens/
│   ├── dashboards/              # Student/Teacher home dashboards
│   ├── features/                # Timetables, Calendars, Scanners, Fee screens
│   ├── academic_screen.dart     # Academics folder router
│   ├── community_screen.dart    # Discussion portal
│   ├── main_screen.dart         # Bottom Navigation scaffold & drawer shell
│   ├── messages_screen.dart     # User-to-user messenger
│   ├── profile_screen.dart      # Standard profile controller
│   └── welcome_screen.dart      # Splash, onboarding, and auth handlers
├── services/
│   ├── api_service.dart         # DIO REST wrapper & Multipart requests
│   ├── app_state_notifier.dart  # Global state listeners
│   ├── auth_service.dart        # JWT token handlers
│   └── cache_service.dart       # SharedPreferences caching
├── theme/
│   ├── colors.dart              # Role base colors
│   └── typography.dart          # Styling fonts
└── widgets/
    ├── common_widgets.dart      # Reusable loading states
    ├── navigation_widgets.dart  # Top and bottom navigation bars
    └── teacher_scaffold.dart    # Teacher shell scaffold
```

---

## 🔧 Troubleshooting

* **Image.file crash on Web**: Fixed. The app has `kIsWeb` platform protection so image assets are loaded securely via `Image.network` under web viewports.
* **Pixel Overflows**: Replaced hardcoded heights and constrained columns with `Expanded`/`Flexible` structures to handle dynamic text scaling on smaller devices without pixel clipping.
