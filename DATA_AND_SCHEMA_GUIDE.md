# 📊 EduSphere — Data Architecture & Schema Guide

This guide provides a comprehensive reference of the data flow, backend/frontend environment configurations, database schemas, and relationships within the EduSphere School ERP ecosystem.

---

## 🔄 1. Data Flow Architecture

The EduSphere system utilizes a hybrid serverless/microservice design centered around **Supabase** as the single source of truth for databases, authentication, and real-time operations.

```mermaid
graph TD
    subgraph Client-Side
        Flutter[Flutter App]
    end

    subgraph Backend-API
        NodeServer[NodeJS/Express Server]
        Prisma[Prisma ORM]
    end

    subgraph Supabase-Platform
        SupaAuth[Supabase Auth]
        PostgreSQL[(Supabase PostgreSQL)]
    end

    %% Client Interactions
    Flutter -- "Direct Queries (Supabase SDK)" --> PostgreSQL
    Flutter -- "Authenticate User" --> SupaAuth

    %% Server Interactions
    NodeServer -- "Read/Write via Prisma" --> Prisma
    Prisma --> PostgreSQL
```

### Flow Roles:
1. **Frontend (Flutter)**:
   - Queries tables directly using the `supabase_flutter` client SDK for fast UI rendering, simple CRUD operations, and real-time message listening.
   - Handles client authentication (login, logout, password updates) using Supabase Auth.
2. **Backend (NodeJS/Express)**:
   - Built to handle complex business logic (e.g., payroll calculations, bulk notifications, automated database backups, scanner updates, custom reports).
   - Interacts with the same PostgreSQL database on Supabase using **Prisma ORM** via direct or pooled database connections (`DATABASE_URL`).
3. **Synchronization**:
   - Because both the NodeJS API and the Flutter client connect to the **same Supabase PostgreSQL database**, any updates made by the NodeJS backend or Flutter app are instantly visible across the entire platform.

---

## ⚙️ 2. Environment Schema Configurations

### 📱 Frontend (Flutter) Configuration
The Flutter application initializes with the Supabase client SDK using keys located in:
📂 **[lib/config/supabase_config.dart](file:///d:/incubation/edusphere/lib/config/supabase_config.dart)**

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://xernedkpgdrvjokokdoa.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1...'; // JWT Anon Key
}
```

### 💻 Backend (NodeJS) Configuration
The backend server uses a `.env` file to manage database connections, authentication credentials, and business parameters.
📂 **[server/.env.example](file:///d:/incubation/edusphere/server/.env.example)** is provided as a template:

| Key | Description | Example Value |
| :--- | :--- | :--- |
| **`PORT`** | Port number for NodeJS Express server | `5001` |
| **`NODE_ENV`** | App environment mode | `development` or `production` |
| **`DATABASE_URL`** | Connection string for Supabase database (pooled) | `postgresql://postgres:[password]@db.[ref].supabase.co:5432/postgres` |
| **`DIRECT_URL`** | Direct connection string for Prisma migrations | `postgresql://postgres:[password]@db.[ref].supabase.co:5432/postgres` |
| **`JWT_SECRET`** | Secret key for signing custom backend tokens | `your_jwt_secret_here` |
| **`COOKIE_SECRET`** | Secret key for cookies encryption | `your_cookie_secret_here` |
| **`REDIS_URL`** | Cache storage URL (for caching / sessions) | `redis://localhost:6379` |
| **`ALLOWED_ORIGINS`**| Allowed CORS domains | `https://edusphere-client.onrender.com` |
| **`CLOUDINARY_*`** | Cloudinary credentials for media upload | Cloudinary credentials (cloud name, API key, API secret) |
| **`SCHOOL_ID`** | Identifier of the active school | `EDU001` |
| **`SCHOOL_NAME`** | Name of the active school | `EduSphere Academy` |
| **`FEE_CURRENCY`** | Local currency for finance modules | `INR` |
| **`SCHOOL_START_TIME`**| Start time for attendance tracking | `08:30` |

---

## 🗄️ 3. Database Schema Reference

EduSphere features two parallel representations of the PostgreSQL database schema:
1. **Raw SQL Schema** (`seed.sql` / `full_schema_setup.sql`) — Configures Supabase PostgreSQL directly.
2. **Prisma ORM Schema** (`server/prisma/schema.prisma`) — Exposes models for NodeJS backend queries.

### 🔑 3.1. Raw SQL Table Definitions

Below are the core tables defined in [seed.sql](file:///d:/incubation/edusphere/seed.sql) and [full_schema_setup.sql](file:///d:/incubation/edusphere/full_schema_setup.sql).

#### 1. `teachers`
Tracks teacher-specific information.
```sql
CREATE TABLE public.teachers (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    department TEXT NOT NULL,
    designation TEXT NOT NULL,
    phone TEXT,
    joining_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
```

#### 2. `students`
Tracks student-specific information.
```sql
CREATE TABLE public.students (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    roll_no INT NOT NULL,
    guardian_name TEXT,
    phone TEXT,
    admission_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
```

#### 3. `attendance`
Tracks daily attendance logs for students.
```sql
CREATE TABLE public.attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    date DATE NOT NULL,
    status TEXT NOT NULL, -- 'Present' (P), 'Absent' (A), 'Leave' (L)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    UNIQUE (student_id, date)
);
```

#### 4. `assignments`
Assignments published by teachers for specific classes.
```sql
CREATE TABLE public.assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    subject TEXT NOT NULL,
    description TEXT,
    due_date DATE,
    class_name TEXT NOT NULL,
    section TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL
);
```

#### 5. `submissions`
Assignment submissions by students.
```sql
CREATE TABLE public.submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assignment_id UUID NOT NULL REFERENCES public.assignments(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    student_name TEXT NOT NULL,
    submitted_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::text, NOW()) NOT NULL,
    grade TEXT DEFAULT 'Pending',
    score TEXT DEFAULT 'Not Graded',
    file_name TEXT,
    UNIQUE (assignment_id, student_id)
);
```

---

### 🗺️ 3.2. Prisma ORM Mapping

In the backend, Prisma bridges PostgreSQL to JavaScript classes. The schemas map as follows:

| Database Table | Prisma Model | Key Fields | Description |
| :--- | :--- | :--- | :--- |
| `auth.users` | `User` | `id`, `email`, `password`, `role` | Base user login details |
| `public.students` | `Student` | `id`, `userId`, `rollNumber`, `currentClassId` | Full student profile linked to `User` |
| `public.teachers` | `Teacher` | `id`, `userId`, `employeeId`, `qualification` | Full teacher profile linked to `User` |
| `public.attendance` | `AttendanceRecord`| `id`, `studentId`, `date`, `status` | Daily attendance log |
| `public.assignments`| `Assignment` | `id`, `title`, `subjectId`, `teacherId` | Academic coursework assignments |
| `public.submissions`| `AssignmentSubmission`| `id`, `assignmentId`, `studentId`, `grade`| Homework submission entries |
| *(Extended Model)* | `StudentFeeLedger` | `id`, `studentId`, `totalPayable`, `status` | Tracks student balances, fees & ledger |
| *(Extended Model)* | `Book` / `LibraryIssue` | `id`, `studentId`, `dueDate`, `status` | Library resource management system |

---

## 🔐 4. Authentication Flow

EduSphere maps system authorization roles directly through user metadata in Supabase Auth:

```mermaid
sequenceDiagram
    participant Flutter as Flutter Client
    participant Auth as Supabase Auth
    participant DB as Postgres Table (public.students/teachers)

    Flutter->>Auth: Login(email, password)
    Auth-->>Flutter: Return Session JWT + raw_user_meta_data
    Note over Flutter: Reads role from metadata:<br/>e.g., "role": "student" or "role": "teacher"
    Flutter->>DB: Query profile based on Auth ID (user.id)
    DB-->>Flutter: Return Name, Class, Department, etc.
```

### Predefined Auth Credentials (Demo Accounts)

You can use these credentials to log in and inspect live data:

| Role | Username / Email | Password | Linked Table / Record |
| :--- | :--- | :--- | :--- |
| 👨‍🎓 **Student** | `alex.rivera@edusmart.edu` | `Student@2024` | `public.students` (Grade 12, Sec A) |
| 👨‍🏫 **Teacher** | `prof.harrison@edusmart.edu` | `Teacher@2024` | `public.teachers` (Physics HOD) |
| 👨‍👩‍👦 **Parent** | `parent.smith@edusmart.edu` | `Parent@2024` | Guardian for student Alex Rivera |
| 👑 **Admin** | `admin@edusmart.edu` | `Admin@2024` | School Administrator |
| 💰 **Accountant** | `accounts@edusmart.edu` | `Account@2024` | Financial Coordinator |
| 🚌 **Transport** | `transport@edusmart.edu` | `Transport@2024`| Transport Coordinator |
