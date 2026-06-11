# 📊 EduSphere — Complete System Architecture & Data Guide

Welcome to the **EduSphere ERP** System and Data Guide. This document explains where the data resides, how the frontend and backend communicate, environment configurations, and contains updated test credentials.

---

## 🔄 1. System & Data Flow Architecture

EduSphere is built using a hybrid serverless/microservices architecture that links the Flutter mobile client and the NodeJS backend server directly to a single **Supabase PostgreSQL** database.

```mermaid
graph TD
    subgraph Client-Side (Flutter App)
        Flutter[Flutter Client]
    end

    subgraph Backend-API (NodeJS Server)
        NodeServer[NodeJS/Express Server]
        Prisma[Prisma ORM]
    end

    subgraph Supabase-Platform (Cloud Backend)
        SupaAuth[Supabase Auth]
        PostgreSQL[(Supabase PostgreSQL)]
    end

    %% Client Interactions
    Flutter -- "Direct DB Queries (Supabase SDK)" --> PostgreSQL
    Flutter -- "User Authentication" --> SupaAuth
    Flutter -- "Complex API Requests" --> NodeServer

    %% Server Interactions
    NodeServer -- "Database Operations via Prisma" --> Prisma
    Prisma --> PostgreSQL
```

### Data Flow Roles:
1. **Frontend (Flutter)**:
   - Queries tables directly using the `supabase_flutter` SDK for student/teacher dashboards, attendance logging, and assignment details.
   - Performs user sign-in and session management directly with **Supabase Auth**.
   - Connects to the NodeJS backend for complex computations, PDFs, and reporting.
2. **Backend (NodeJS/Express)**:
   - Built to handle heavy backend tasks, backups, scheduling, and database management.
   - Maps the PostgreSQL database using **Prisma ORM** to execute migrations and bulk updates.
3. **Database Consistency**:
   - Since both Flutter and NodeJS connect to the **same PostgreSQL database instance on Supabase**, data is immediately updated in real-time on the mobile app.

---

## ⚙️ 2. Environment Configurations & Files

The project coordinates its database and backend connectivity across both frontend and backend configurations:

### 📱 A. Mobile Client Config (Flutter)
Located in:
📂 **[lib/config/supabase_config.dart](file:///d:/incubation/edusphere/lib/config/supabase_config.dart)**
- Contains the active Supabase API URL and anonymous API Key used to initialize the client app.
```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://bstevdkjqjzaglayicdg.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1...'; // Anon JWT Key
}
```

📂 **[lib/config/api_config.dart](file:///d:/incubation/edusphere/lib/config/api_config.dart)**
- Configures base URL paths for API endpoints.
- Toggles between the live server (hosted on Render) and local development server depending on the compilation environment:
```dart
static const bool useLiveBackend = true; // Set to false to use localhost:5001
```

---

### 💻 B. Backend Config (NodeJS Server)
Located in:
📂 **[server/.env](file:///d:/incubation/edusphere/server/.env)**
- Defines the active environment configurations, database connection pools, security secrets, and local parameters.

| Env Variable | Purpose / Usage | Example |
| :--- | :--- | :--- |
| `PORT` | Local server port for Express API | `5001` |
| `DATABASE_URL` | Pooled connection (Port 6543) for Node queries | `postgresql://postgres.bstevdkjqjzaglayicdg...pooler.supabase.com:6543/postgres?pgbouncer=true` |
| `DIRECT_URL` | Direct connection (Port 5432) for running migrations | `postgresql://postgres.bstevdkjqjzaglayicdg...pooler.supabase.com:5432/postgres` |
| `SCHOOL_NAME` | Active school identity parameter | `EduSphere Academy` |

---

## 🗄️ 3. Database Seeding & Source Files

Database schemas and seed data are managed in the following files:

1. **SQL Schema & Seed (`seed.sql` / `full_schema_setup.sql`)**:
   - Defines raw table structures (`public.teachers`, `public.students`, `public.attendance`, `public.assignments`, `public.submissions`) in Supabase.
2. **Prisma Schema (`server/prisma/schema.prisma`)**:
   - Translates database tables into Prisma Client models for server-side Javascript code.
3. **Seed Scripts (`server/prisma/seed-new.js`)**:
   - Seeds realistic mock databases (500 students, 50 teachers, admins) directly into the PostgreSQL schema and registers their matching credentials in Supabase Auth.

---

## 🔐 4. Updated Test Credentials (Demo Logins)

Below is the verified list of test accounts configured in the active Supabase environment.

> [!IMPORTANT]
> The password for all realistic seeded users (`@edusphere.edu` domain) is: **`edusphere`**
>
> The password for the legacy demo users (`@edusmart.edu` domain) is: **`Student@2024`** or **`Teacher@2024`**

### Seeded Accounts list (Password: **`edusphere`**)

| Role | Email Address | Password | Profile Source |
| :--- | :--- | :--- | :--- |
| 👑 **Admin** | `admin@edusphere.edu` | **`edusphere`** | Administrator |
| 👨‍🏫 **Teacher (HOD)** | `teacher1@edusphere.edu` | **`edusphere`** | Teacher 1 Profile (Physics) |
| 👨‍🏫 **Teacher (Lecturer)**| `teacher2@edusphere.edu` | **`edusphere`** | Teacher 2 Profile |
| 👨‍🎓 **Student (12th)** | `student1@edusphere.edu` | **`edusphere`** | Student 1 Profile |
| 👨‍🎓 **Student (10th)** | `student2@edusphere.edu` | **`edusphere`** | Student 2 Profile |
| 👨‍👩‍👦 **Parent** | `parent@edusphere.edu` | **`edusphere`** | Student Guardian Profile |
| 💰 **Accountant** | `accountant@edusphere.edu` | **`edusphere`** | Finance Manager |
| 🚌 **Transport** | `transport@edusphere.edu` | **`edusphere`** | Transport/Staff Manager |

---

## 📦 5. App Compilation & Build Details

### Gradle Build Fix
To support building on systems with multi-drive setups (e.g. Pub Cache on `C:` and Project Code on `D:`), Kotlin's incremental compiler relative-path check has been bypassed.
📂 Config file: **[android/gradle.properties](file:///d:/incubation/edusphere/android/gradle.properties)**
```properties
kotlin.incremental=false
```

### Release APK Build Command
```bash
flutter clean
flutter build apk --release
```
- **Output release file location:** [app-release.apk](file:///d:/incubation/edusphere/app-release.apk) (copied to project root).

---

## 📱 6. Mobile Screen to Supabase Mapping & Real-time Guide

Below is the complete mapping of Flutter mobile features/screens to their respective Supabase tables, including the data fields and real-time synchronization channels.

| Feature / Screen | File Path | Supabase Table | Key Fields & Mapping | Real-Time Sync Channel |
| :--- | :--- | :--- | :--- | :--- |
| **Academic Calendar** | [academic_calendar_screen.dart](file:///d:/incubation/edusphere/lib/screens/features/academic_calendar_screen.dart) | `SchoolCalendar` | `title`, `description`, `date`, `type`, `createdBy` | Postgres changes on `SchoolCalendar` |
| **User Profile** | [profile_screen.dart](file:///d:/incubation/edusphere/lib/screens/profile_screen.dart) | `User`, `Teacher`, `Student` | `firstName`, `lastName`, `email`, `phone`, `gender`, `dob`, `designation`, `department` | Direct read/write on changes |
| **Assignments** | [assignments_screen.dart](file:///d:/incubation/edusphere/lib/screens/features/assignments_screen.dart) | `Assignment`, `AssignmentSubmission` | `title`, `description`, `subject`, `dueDate`, `classId`, `status` | Postgres changes on `Assignment` and `AssignmentSubmission` |
| **Announcements** | [announcements_screen.dart](file:///d:/incubation/edusphere/lib/screens/features/announcements_screen.dart) | `Announcement` | `title`, `content`, `priority`, `targetAudience`, `createdAt` | Postgres changes on `Announcement` |
| **Community Feed** | [community_screen.dart](file:///d:/incubation/edusphere/lib/screens/community_screen.dart) | `CommunityPost` | `content`, `category`, `author_name`, `likes`, `comments` (JSONB) | Postgres changes on `CommunityPost` |
| **Services / Tickets** | [services_screen.dart](file:///d:/incubation/edusphere/lib/screens/features/services_screen.dart) | `ServiceRequest` | `title`, `category` (Type), `desc`, `status`, `createdAt`, `userId` | Postgres changes on `ServiceRequest` |
| **Fee Approvals** | [fee_approvals_screen.dart](file:///d:/incubation/edusphere/lib/screens/features/fee_approvals_screen.dart) | `fee_waiver_requests` | `student_name`, `class`, `type`, `fee_head`, `original_amount`, `requested_amount`, `reason`, `status` | Postgres changes on `fee_waiver_requests` |
| **Student Directory** | [student_directory_screen.dart](file:///d:/incubation/edusphere/lib/screens/features/student_directory_screen.dart) | `Student` (joins `User`, `Class`) | `admissionNumber`, `status`, `User(firstName, lastName, email)`, `Class(name)` | Postgres changes on `Student` |

