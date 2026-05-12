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
flutter gen-l10n                            # Regenerate from ARB (l10n.yaml controls options)
```

Firebase Functions (in `functions/`):
```bash
npm install
npm run lint
firebase emulators:start --only functions
firebase functions:secrets:set RESEND_API_KEY
```

## Architecture

**GovChat** is a multi-role secure government communication platform built with Flutter + Firebase.

### Role routing

Login routing lives entirely in `LoginController.login()`. After Firebase Auth it reads `users/{uid}` and routes to:
- `primary_admin` → `MainScreen`. If the `users/{uid}` doc is **absent**, the user is bootstrapped as `primary_admin` on the spot (first-run case).
- `admin` → `AdminMainScreen`, but forced to `ChangePasswordScreen` when `firstLogin == true || mustChangePassword == true`.
- `employee` → `EmployeeMainScreen`. The controller loads `employees/{uid}` to get `departmentId`; if it is empty it derives the slug via `_slugDepartment()` on the `department` field and writes it back to Firestore.

Each role has its own UI tree under `lib/roles/`. Every role-protected screen must call `SessionManager.instance.ensureRole(context, allowedRoles: [...])` in `initState` via `addPostFrameCallback`. It re-validates role, status, and `organizationId` against Firestore and calls `logout()` on any mismatch.

### State management

Provider + ChangeNotifier. Controllers expose `isLoading`, `errorMessage`, `formKey`. Controllers **self-initialize in their constructors** — never call `_init()` externally. Dispose all `TextEditingController`s, `StreamSubscription`s, and `Timer`s in `dispose()`.

### Firebase layer

`FirebaseService` singleton wraps Auth, Firestore (`FirebaseService.instance.firestore`), and Cloud Functions (region `us-central1`). `PreferencesManager` singleton wraps SharedPreferences — must be initialized with `await PreferencesManager().init()` before use (done in `main()`). Models use `fromJson()`/`toJson()`; Timestamps are converted to DateTime in `fromJson`.

### Session

`SessionManager.instance.logout()` signs out, clears SharedPreferences, evicts the in-memory E2EE key cache via `E2eeManager.clearCache()`, and navigates to `LoginScreen`. The 5-minute inactivity timeout is wired at the `MyApp` level via `Listener` + `WidgetsBindingObserver` — not inside `SessionManager`.

### Chat system

`ChatController` is the single controller for all chat types. The optional `messagesPath` constructor parameter selects the Firestore path:

| `messagesPath` | Chat type | Member resolution for E2EE |
|---|---|---|
| `null` (default) | Department | employees matching `organizationId` + `departmentId` |
| contains `/private_chats/` | 1-to-1 private | `participants` array on the conversation doc |
| contains `/org_chats/` | Org-wide | all active employees in the org |

Default department path: `organizations/{orgId}/departments/{deptId}/messages`

`departmentId` normalization: `replaceAll(r'[^a-zA-Z0-9_-]', '_').toLowerCase()` — applied by `_slugDepartment()` at login and by `_sanitize()` inside `ChatController` at send time. Both sides must produce identical slugs.

**Message soft-delete**: set `isDeleted: true` in Firestore. The stream filters these on the client (`where((m) => !m.isDeleted)`). Typing indicators are stored on the chat/department doc as `{typing: {displayId: Timestamp}}`. Read receipts use `readBy: FieldValue.arrayUnion([displayId])` — these are **displayIds**, not Firebase UIDs.

### End-to-end encryption (E2EE)

All messages are encrypted client-side before leaving the device. `E2eeManager` coordinates:

- **Key generation**: X25519 key pair generated once per device at first login via `E2eeManager.initializeKeys(uid)` (called fire-and-forget in `LoginController`). Private key stored in `flutter_secure_storage`. Public key written to both `users/{uid}.e2eePublicKey` and `employees/{uid}.e2eePublicKey` (both locations are tried on read so it works for all roles).
- **Private chat**: deterministic X25519 key agreement — both sides derive the same AES-256 key independently with no extra Firestore round-trip.
- **Group / department / org**: a random AES-256 key is created by the first member, wrapped per-member with X25519, and stored at `{conversationPath}/groupKey/{uid}` (fields: `wrappedKey`, `nonce`, `creatorUid`, `creatorPublicKey`). New members get a copy distributed to them when they first open the chat.
- **Algorithm**: AES-256-GCM. Ciphertext and nonce are base-64 strings stored in `encryptedText`/`iv` (text) and `encryptedMediaUrl`/`mediaIv` (media URLs). The `text` field is always `''` for encrypted messages.
- **In-memory cache**: `E2eeKeyStore` caches derived keys both in memory and in secure storage. `E2eeManager.clearCache()` evicts only the in-memory layer; keys survive restarts.

`ChatController._awaitEncryptionKey()` is awaited before every send. If the key is unavailable (group key not yet distributed), the UI shows a retry banner. A Firestore listener on `{conversationPath}/groupKey/{uid}` auto-retries when the key doc appears.

### Logging

Two services both write to the global `logs` collection:

- **`LoggingService`** — org-scoped. Requires a non-empty `organizationId`. Derives a `category` from `actionType` (authentication / employee / chat / groups / security). Always call fire-and-forget (`.ignore()` or don't await); never block the critical path.
- **`ActivityLogService`** — global, no `organizationId` required. Used by `primary_admin` audit screen. Also calls `updateLoginActivity()` to stamp `users/{uid}.lastLoginAt`.

### Cloud Functions

Both functions are callable, region `us-central1`, max 10 instances:

- `createAdminWithCode` — provisions a new organization + admin: generates an 8-digit temp password, creates Auth user, writes `organizations/{orgId}` + `users/{uid}`, emails credentials via Resend. Reads `RESEND_API_KEY` from Firebase Secret Manager.
- `sendAccessApprovedEmail` — called after an admin approves an access request.

## Firestore Collections

- `users/{uid}` — all roles; fields: `role`, `status`, `organizationId`, `mustChangePassword`, `firstLogin`, `e2eePublicKey`, `lastLoginAt`
- `employees/{uid}` — employee profiles; fields: `organizationId`, `departmentId`, `department`, `displayId`, `role`, `status`, `e2eePublicKey`
- `accessRequests/{id}` — pending employee requests scoped by `organizationId`
- `organizations/{orgId}` — org metadata; sub-collections: `departments/{deptId}/messages`, `departments/{deptId}/private_chats/{chatId}/messages`, `org_chats/{chatId}/messages`
- `logs` — shared collection for both logging services
- `{conversationPath}/groupKey/{uid}` — per-member wrapped E2EE group keys

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
    services/
      session_manager.dart
      logging_service.dart       # Org-scoped log (admin review)
      activity_log_service.dart  # Global log (primary_admin audit)
      encryption/                # E2eeManager, E2eeCrypto, E2eeKeyStore
    providers/           # LocaleProvider
    Widgets/             # Shared form widgets (CustomTextField, etc.)
  models/                # Shared data models — reuse before creating new ones
  roles/
    Admin/features/      # requests, employees, groups, logs, profile, Main (nav shell)
    primary Admin/Features/  # organizations, audit, profile, dashboard
    employee/features/   # chat, chat_list, home, new_chat, profile
functions/               # Node.js 24 Firebase Cloud Functions (email via Resend)
```

## Conventions

- **Package name**: `projects` (from `pubspec.yaml`). All project-internal imports use `package:projects/...`.
- **Files:** `snake_case.dart` | **Classes/Widgets:** `PascalCase` | **Screens:** suffix `Screen`
- **UI:** Dark theme only. Use `AppColors.*` and `AppSizes.*` — never raw literals.
- **Responsiveness:** `ScreenUtilInit` wraps the app (design size 375×812). Use `AppSizes.h*`, `AppSizes.w*`, `AppSizes.sp*`, `AppSizes.r*`, `AppSizes.ph*`, `AppSizes.pw*`.
- **Typography:** `GoogleFonts.manrope`; use `AppColors` text color constants.
- **Nav labels:** uppercase to match `BottomNavigationBar` styling.
- **Imports order:** dart sdk → third-party → project (`package:projects/...`) → relative (within feature).
- **New admin tabs:** extend `_screens` and `BottomNavigationBarItem` lists in `roles/Admin/features/Main/admin_main_screen.dart`. Primary admin nav shell is in `roles/primary Admin/Features/Main/main_screen.dart`.
- **New features:** keep self-contained under feature folder (`data/`, `widgets/`, `view/`); share primitives via `core/`.
- **Role guard:** call `SessionManager.instance.ensureRole(context, allowedRoles: [...])` in `initState` via `addPostFrameCallback` before rendering any role-specific screen.
- **Localization:** all user-visible strings go in `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`. Run `flutter gen-l10n` after any ARB change. ARB keys must be unique across the entire file — duplicates cause analyzer errors in the generated Dart.
