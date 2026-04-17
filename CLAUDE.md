# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                              # Install dependencies
flutter run -d <device_id>                  # Run on device
flutter analyze                             # Lint
dart format lib test                        # Format all
dart format lib/path/to/file.dart           # Format single file
flutter test                                # All tests
flutter test test/file.dart --name "<name>" # Single test
flutter build apk --release                 # Android release
flutter clean && flutter pub get            # Fix broken builds
```

Firebase Functions (in `functions/`):
```bash
npm install
npm run lint
firebase emulators:start --only functions
```

## Architecture

**GovChat** is a multi-role secure government communication platform built with Flutter + Firebase.

**Roles:** `employee`, `admin`, `primary_admin` — each has a separate UI tree under `lib/roles/`. Login routing happens in `LoginController.login()` which reads the `role` field from `users/{uid}` and navigates to `EmployeeChatScreen`, `AdminMainScreen`, or `MainScreen` respectively.

**State management:** Provider + ChangeNotifier. Controllers expose `isLoading`, `errorMessage`, `formKey`. Dispose TextEditingControllers/StreamSubscriptions in `dispose()`. Controllers self-initialize via `_init()` in their constructors — do not call init externally.

**Firebase layer:** `FirebaseService` singleton wraps Auth, Firestore (`FirebaseService.instance.firestore`), and Cloud Functions (region `us-central1`). `PreferencesManager` singleton wraps SharedPreferences — must be initialized with `await PreferencesManager().init()` before use (done in `main()`). Models use `fromJson()`/`toJson()`; Timestamps are converted to DateTime in `fromJson`.

**Session:** `SessionManager.instance.logout()` signs out, clears prefs, and pushes to `LoginScreen`. `SessionManager.instance.ensureRole()` validates role + status + org against Firestore on screen init. The 5-minute inactivity timeout is wired at the `MyApp` level via `Listener` + `WidgetsBindingObserver` — not in `SessionManager`.

**Chat:** Messages live at `organizations/{orgId}/departments/{deptId}/messages`. `departmentId` is normalized to lowercase with non-alphanumeric chars replaced by `_`. Employee's `departmentId` is derived from `department` field via `_slugDepartment()` at login time and stored back to Firestore if missing.

## Firestore Collections

- `users/{uid}` — all roles; fields: `role`, `status`, `organizationId`, `mustChangePassword`, `firstLogin`
- `employees/{uid}` — employee profiles; fields: `organizationId`, `departmentId`, `department`, `displayId`, `role`, `status`
- `accessRequests/{id}` — pending employee requests scoped by `organizationId`
- `organizations/{orgId}` — org metadata; sub-collection `departments/{deptId}/messages`

## Cloud Functions

`createAdminWithCode` — called by primary_admin to create a new organization + admin. Generates a temp password, creates Auth user, writes `organizations` + `users` docs, sends credentials via Resend email. Secret `RESEND_API_KEY` stored in Firebase Secret Manager.

`sendAccessApprovedEmail` — called after an admin approves an access request.

## Key Directories

```
lib/
  auth/                  # Login, access request, change password flows + controllers
  core/
    theme/               # Dark-only ThemeData, AppColors
    constants/           # AppSizes (responsive sizing wrappers)
    datasource/
      local_data/        # PreferencesManager
      remote_data/       # FirebaseService
    services/            # SessionManager
    Widgets/             # Shared form widgets (CustomTextField, etc.)
  models/                # Shared data models — reuse before creating new ones
  roles/
    Admin/features/      # requests, employees, logs, profile, Main (nav shell)
    primary Admin/Features/  # organizations, audit, profile, dashboard
    employee/features/   # chat UI
functions/               # Node.js Firebase Cloud Functions (email via Resend)
```

## Conventions

- **Files:** `snake_case.dart` | **Classes/Widgets:** `PascalCase` | **Screens:** suffix with `Screen`
- **UI:** Dark theme only. Use `AppColors.*` and `AppSizes.*` — never raw literals.
- **Responsiveness:** `ScreenUtilInit` wraps the app (design size 375×812). Use `AppSizes.h*`, `AppSizes.w*`, `AppSizes.sp*`, `AppSizes.r*`, `AppSizes.ph*`, `AppSizes.pw*`. Radius values use `AppSizes.r*`.
- **Typography:** `GoogleFonts.manrope`; use `AppColors` text color constants.
- **Nav labels:** uppercase to match `BottomNavigationBar` styling.
- **Imports order:** dart sdk → third-party → project (`package:projects/...`) → relative (within feature).
- **New admin tabs:** extend `_screens` and `BottomNavigationBarItem` lists in `roles/Admin/features/Main/admin_main_screen.dart`. Primary admin nav shell is in `roles/primary Admin/Features/Main/main_screen.dart`.
- **New features:** keep self-contained under feature folder (`data/`, `widgets/`, `view/`); share primitives via `core/`.
- **Role guard:** call `SessionManager.instance.ensureRole(context, allowedRoles: [...])` in `initState` via `addPostFrameCallback` before rendering any role-specific screen.
