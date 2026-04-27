# Smart Task Planner

A production-ready, cross-platform task management and calendar app for **Windows** and **Android**, built with a single Flutter codebase.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter 3 (Dart) — single codebase for Android + Windows |
| State Management | flutter_bloc (BLoC pattern) |
| Navigation | go_router |
| Backend / Realtime | Supabase (PostgreSQL + Realtime + Auth + Edge Functions) |
| Local Database | Drift (SQLite, offline-first) |
| Push Notifications | Firebase Cloud Messaging (FCM) + flutter_local_notifications |
| Auth | Supabase Auth (Email, Google, Microsoft) |
| Forms | reactive_forms |
| Charts | fl_chart |
| Calendar | table_calendar |
| DI | get_it + injectable |

---

## Architecture

```
Clean Architecture + BLoC

┌──────────────────────────────────────────────┐
│               Presentation Layer              │
│  Pages → BLoC (Events → States) → Widgets    │
├──────────────────────────────────────────────┤
│               Domain Layer                   │
│  Entities │ Repository Interfaces │ Use Cases │
├──────────────────────────────────────────────┤
│               Data Layer                     │
│  Models │ Local (Drift) │ Remote (Supabase)  │
│  Repository Implementations                  │
├──────────────────────────────────────────────┤
│               Services Layer                 │
│  NotificationService │ SyncService           │
└──────────────────────────────────────────────┘
```

---

## Project Structure

```
smart_task_planner/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── app.dart                     # Root widget, providers
│   ├── config/
│   │   ├── router.dart              # go_router navigation
│   │   └── theme.dart               # Light / Dark themes
│   ├── core/
│   │   ├── constants/               # App-wide constants
│   │   ├── di/                      # Dependency injection
│   │   ├── errors/                  # Failure types
│   │   └── usecases/               # UseCase base classes
│   ├── domain/
│   │   ├── entities/               # Task, Category, AppUser
│   │   ├── repositories/           # Abstract repo interfaces
│   │   └── usecases/              # Business logic use cases
│   ├── data/
│   │   ├── models/                 # JSON-serializable models
│   │   ├── datasources/
│   │   │   ├── local/              # Drift local database
│   │   │   └── remote/             # Supabase data sources
│   │   └── repositories/          # Concrete implementations
│   ├── presentation/
│   │   ├── blocs/                  # auth / task / calendar / theme
│   │   ├── pages/                  # All screen pages
│   │   │   ├── auth/
│   │   │   ├── dashboard/
│   │   │   ├── tasks/
│   │   │   ├── calendar/
│   │   │   ├── stats/
│   │   │   └── settings/
│   │   ├── shell/                  # Main navigation shell
│   │   └── widgets/               # Reusable components
│   └── services/
│       ├── notification_service.dart
│       └── sync_service.dart
├── supabase/
│   ├── migrations/
│   │   └── 001_initial_schema.sql  # Full DB schema with RLS
│   └── functions/
│       └── send-reminders/         # Edge Function for FCM
├── pubspec.yaml
└── README.md
```

---

## Database Schema (Supabase / PostgreSQL)

```
user_profiles       categories          tasks
─────────────       ──────────          ─────
id (UUID PK)        id (UUID PK)        id (UUID PK)
email               user_id (FK)        user_id (FK)
display_name        name                title
avatar_url          color_value         description
fcm_token           icon                deadline
created_at          created_at          priority (enum)
updated_at                              status (enum)
                                        tags (text[])
reminders                               category_id (FK)
─────────                               recurrence_rule (JSONB)
id (UUID PK)                            estimated_minutes
task_id (FK)                            pomodoro_count
user_id (FK)                            is_deleted
remind_at                               created_at
is_sent                                 updated_at
created_at
```

**Security:** All tables are protected with Row Level Security (RLS).  
Each user can only read/write their own data.

---

## Features

### Core
- ✅ Create, edit, delete tasks (swipe to delete)
- ✅ Deadline (date + time picker)
- ✅ Priority: Low / Medium / High (color-coded)
- ✅ Status: Open / In Progress / Done
- ✅ Tags / categories
- ✅ Recurring tasks (daily, weekly, monthly)
- ✅ Estimated time + Pomodoro counter
- ✅ Full-text search with filters

### Calendar
- ✅ Monthly / Weekly view (table_calendar)
- ✅ Drag-and-drop task rescheduling
- ✅ Priority-colored markers
- ✅ Day-detail task list
- ✅ Quick "Add Task" for selected date

### Sync
- ✅ Offline-first with Drift (SQLite)
- ✅ Supabase Realtime push updates
- ✅ Auto-sync on reconnect
- ✅ Last-writer-wins conflict resolution
- ✅ Manual force-sync

### Auth
- ✅ Email / Password sign in + register
- ✅ Google Sign-In
- ✅ Microsoft (Azure AD) OAuth
- ✅ Password reset via email

### Notifications
- ✅ Local notifications before deadlines
- ✅ FCM push for remote reminders
- ✅ Supabase Edge Function scheduler

### UI/UX
- ✅ Material 3 design
- ✅ Dark Mode + Light Mode + System
- ✅ Adaptive layout: NavigationBar (mobile) + NavigationRail (desktop)
- ✅ Fluid animations (flutter_animate)
- ✅ Eisenhower Matrix quadrant view
- ✅ Productivity stats with charts
- ✅ Today-focus dashboard

---

## Getting Started

### 1. Prerequisites

```bash
flutter --version   # >= 3.19
dart --version      # >= 3.3
```

### 2. Clone & Install

```bash
git clone <your-repo-url>
cd smart_task_planner
flutter pub get
```

### 3. Set Up Supabase

1. Create a project at [supabase.com](https://supabase.com)
2. Run `supabase/migrations/001_initial_schema.sql` in the SQL Editor
3. Enable **Google** and **Azure** providers in Authentication → Providers
4. Copy your project URL and anon key

### 4. Set Up Firebase

```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

Select Android (and Windows if supported for FCM).  
This creates `google-services.json` and `firebase_options.dart`.

### 5. Configure Environment

```bash
# Run with Supabase credentials injected
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

Or create a `.env` file and use `--dart-define-from-file=.env`.

### 6. Generate Code

```bash
# Drift DB + Injectable DI + Freezed models
dart run build_runner build --delete-conflicting-outputs
```

### 7. Run

```bash
# Android
flutter run -d android

# Windows
flutter run -d windows
```

---

## Deployment

### Android

```bash
# Build release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# Build Android App Bundle (for Play Store)
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

**Google Play Store:** Upload the `.aab` via the Play Console.  
Add your SHA-1 fingerprint to Firebase and Supabase Google OAuth settings.

### Windows

```bash
# Build release executable
flutter build windows --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...

# Output: build/windows/x64/runner/Release/
```

Package with **MSIX** for the Microsoft Store:
```bash
flutter pub add msix
flutter pub run msix:create
```

---

## Supabase Edge Functions

```bash
# Deploy reminder scheduler
supabase functions deploy send-reminders \
  --env-file supabase/.env

# Schedule via pg_cron (in Supabase SQL Editor):
SELECT cron.schedule(
  'send-reminders',
  '* * * * *',   -- every minute
  $$SELECT net.http_post(
      url := 'https://<project-ref>.supabase.co/functions/v1/send-reminders',
      headers := '{"Authorization":"Bearer <service-role-key>"}'::jsonb
  ) AS request_id;$$
);
```

---

## Step-by-Step Implementation Plan

| Week | Milestone |
|---|---|
| 1 | Flutter project setup, Supabase project, DB schema, auth flow |
| 2 | Task CRUD, Drift local DB, offline sync basics |
| 3 | Calendar page, drag-and-drop, recurrence engine |
| 4 | Notifications (local + FCM), Edge Function |
| 5 | Stats page, Eisenhower matrix, search & filters |
| 6 | Windows desktop layout, NavigationRail, MSIX packaging |
| 7 | Testing (unit + widget + integration), CI/CD setup |
| 8 | Play Store + Microsoft Store submission, production hardening |

---

## Optional Features (Roadmap)

- [ ] Pomodoro timer with work/break cycles
- [ ] AI prioritization suggestions (Supabase Edge Function + OpenAI)
- [ ] Voice input for task creation
- [ ] PDF/CSV export
- [ ] Android Home Screen Widget (home_widget package)
- [ ] Windows System Tray integration
- [ ] iCloud / Google Calendar sync
- [ ] Collaborative tasks (shared with team members)
