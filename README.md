# GovChat

> **Powering Secure Communication at the Core of Every Organization.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-3.10-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Security](https://img.shields.io/badge/Security-E2EE%20%2B%20RBAC-4CAF50)](https://owasp.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen)](https://github.com)

---

## Overview

GovChat is a secure, production-ready communication platform engineered for government bodies, enterprises, and regulated organizations that demand the highest standards of data integrity, confidentiality, and operational transparency.

Traditional messaging tools are not built for the regulatory and security requirements of institutional communication. GovChat addresses this gap by delivering a purpose-built platform that enforces strict role-based access, end-to-end encrypted messaging, auditable activity logs, and a backend architecture where all sensitive operations are handled exclusively through validated Cloud Functions — never exposed directly to the client.

Built on Flutter and Firebase, GovChat operates across Android, iOS, and web from a single codebase while scaling effortlessly to support organizations of any size.

---

## Key Features

### Secure Authentication
- Firebase Authentication with server-side session validation on every role-protected screen
- Mandatory password change on first login
- Inactivity timeout with automatic session termination
- Access request workflow requiring admin approval before any user enters the system

### Real-Time Messaging
- Department-scoped chat with instant Firestore updates
- Support for text, images, audio, and video messages
- Soft-delete architecture for message management
- Cached media delivery via `cached_network_image` and `firebase_storage`

### Role-Based Access Control (RBAC)
- Three distinct role tiers: `employee`, `admin`, `primary_admin`
- Separate UI trees per role with server-side role validation
- `SessionManager.ensureRole()` enforced in `initState` on every protected screen
- Organization-scoped data isolation — cross-tenant data access is structurally impossible

### Cloud Functions and Backend Security
- All privileged operations (user creation, organization provisioning, email dispatch) run exclusively inside Cloud Functions
- Temporary credentials generated server-side and delivered via transactional email through Resend
- Client code never holds administrative Firebase credentials

### Firebase Integration
- Firestore with structured collection hierarchy and server-enforced security rules
- Firebase Storage with per-organization access scoping
- Firebase Cloud Functions (Node.js 24, region `us-central1`)
- `firebase-admin` SDK used server-side only

### End-to-End Encryption
- Message content encrypted client-side using the `cryptography` package (AES-GCM / X25519)
- Encryption keys stored in device-isolated secure storage via `flutter_secure_storage`
- Keys never transmitted to or stored on the server

### Responsive UI/UX
- Dark-only theme with a consistent design language via `AppColors` and `AppSizes`
- Responsive layout powered by `flutter_screenutil` (design base: 375 × 812)
- `GoogleFonts.manrope` typography throughout

### Multilingual Support
- Full Arabic and English localization via Flutter's ARB/`intl` pipeline
- Right-to-left layout support
- Runtime locale switching managed by `LocaleProvider`

### Audit and Activity Logging
- Immutable activity log per organization capturing login, logout, and administrative actions
- Primary admin audit screen with filter and search across all organizations
- Tamper-evident log entries stored in Firestore with server timestamps

### Scalable Architecture
- Multi-tenant data model with organization-level isolation
- Stateless Cloud Functions scale automatically with demand
- Provider + ChangeNotifier state management with clear lifecycle boundaries

---

## Security

GovChat is designed with security as a first-class requirement, informed by OWASP guidelines and NIST Secure Software Development Framework (SSDF) principles.

| Layer | Control |
|-------|---------|
| **Authentication** | Firebase Auth with server-side session validation on every protected route |
| **Authorization** | RBAC enforced both client-side (`ensureRole`) and in Firestore Security Rules |
| **Transport** | All Firebase traffic over TLS 1.2+ — no plaintext communication |
| **Data at Rest** | Messages encrypted end-to-end before leaving the client device |
| **Key Management** | Encryption keys stored in OS-level secure storage; never synced to the cloud |
| **Backend Isolation** | Sensitive operations are Cloud Functions only — no direct admin SDK access from clients |
| **Secret Management** | API keys (e.g., `RESEND_API_KEY`) stored in Firebase Secret Manager, not in source code |
| **Input Validation** | All user input validated server-side inside Cloud Functions before Firestore writes |
| **Session Security** | 5-minute inactivity timeout; session cleared on logout and role mismatch |
| **Dependency Hygiene** | `flutter_lints` enforced; private package registry (`publish_to: none`) |

**GitHub Secret Protection:** No credentials, API keys, or service account files are committed to the repository. Firebase configuration is generated per environment and excluded via `.gitignore`. A full security audit is available in [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md).

---

## Tech Stack

| Technology | Purpose | Version |
|------------|---------|---------|
| Flutter | Cross-platform UI framework | 3.x |
| Dart | Application language | ^3.10.7 |
| Firebase Core | Firebase SDK initialization | ^3.13.0 |
| Firebase Auth | Authentication and session management | ^5.5.2 |
| Cloud Firestore | Real-time NoSQL database | ^5.6.6 |
| Firebase Storage | Media file storage | ^12.4.10 |
| Cloud Functions | Serverless backend (Node.js 24) | ^5.3.3 |
| Provider | State management | ^6.1.1 |
| flutter_screenutil | Responsive layout scaling | ^5.9.0 |
| cryptography | End-to-end encryption (AES-GCM, X25519) | ^2.0.5 |
| flutter_secure_storage | Secure local key storage | ^9.2.2 |
| google_fonts | Typography (Manrope) | ^6.1.0 |
| intl / ARB | Localization (EN + AR) | ^0.20.2 |
| Resend | Transactional email (Cloud Functions) | ^3.2.0 |
| ESLint | Cloud Functions linting | ^8.15.0 |
| flutter_lints | Dart/Flutter static analysis | ^6.0.0 |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Flutter Client                     │
│  ┌───────────┐  ┌───────────┐  ┌──────────────────┐    │
│  │ Employee  │  │   Admin   │  │  Primary Admin   │    │
│  │    UI     │  │    UI     │  │       UI         │    │
│  └─────┬─────┘  └─────┬─────┘  └────────┬─────────┘    │
│        │              │                 │               │
│  ┌─────▼──────────────▼─────────────────▼──────────┐   │
│  │   Provider + ChangeNotifier (State Management)  │   │
│  └──────────────────────┬──────────────────────────┘   │
│                         │                               │
│  ┌──────────────────────▼──────────────────────────┐   │
│  │   FirebaseService (Auth · Firestore · Storage)  │   │
│  └──────────────────────┬──────────────────────────┘   │
└─────────────────────────┼───────────────────────────────┘
                          │ TLS
┌─────────────────────────▼───────────────────────────────┐
│                    Firebase Platform                     │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Firestore   │  │  Auth        │  │    Storage    │  │
│  │  (RBAC +     │  │  (Sessions)  │  │  (Media)      │  │
│  │   Rules)     │  └──────────────┘  └───────────────┘  │
│  └──────────────┘                                        │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Cloud Functions (us-central1)                   │   │
│  │  createAdminWithCode · sendAccessApprovedEmail   │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Frontend:** Flutter with a role-separated screen tree. Each role (`employee`, `admin`, `primary_admin`) has its own navigation shell under `lib/roles/`. State is managed via Provider; controllers self-initialize and manage their own lifecycle.

**Backend:** Node.js 24 Cloud Functions handle all privileged operations. No admin credentials exist on the client. The `firebase-admin` SDK is used exclusively server-side.

**Database:** Firestore with a multi-tenant hierarchy (`organizations/{orgId}/departments/{deptId}/messages`). Security rules enforce organization-scoped access at the database level.

**Security Layer:** E2EE handled client-side before any data leaves the device. `SessionManager` validates role, status, and organization on every protected screen. Inactivity timeout is enforced at the `MyApp` root via `Listener` + `WidgetsBindingObserver`.

---

## Demo Accounts

A sandboxed demo organization is available for evaluating GovChat without setting up your own Firebase project. These accounts use isolated test data with no access to real user information.

| Role | Email | Password |
|------|-------|----------|
| Employee | `demo.employee@govchat.demo` | `Demo@GovChat1` |

> **Note:** Demo accounts are read-only and operate in an isolated demo organization. No real data is accessible. The demo environment resets periodically.

To request an admin-level demo for the web dashboard, contact the team directly.

---

## Installation

### Prerequisites

- Flutter SDK `^3.10.7`
- Dart SDK `^3.10.7`
- Node.js 24
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)
- A Firebase project with **Firestore**, **Auth**, **Storage**, and **Functions** enabled

### Steps

**1. Clone the repository**

```bash
git clone https://github.com/abdulrhmanALyousef/GovChat.git
cd GovChat
```

**2. Install Flutter dependencies**

```bash
flutter pub get
```

**3. Configure Firebase**

Firebase credential files are gitignored. You must generate them for your own project:

```bash
firebase login
flutterfire configure
```

This generates:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Template files (`.example` suffix) are provided for reference. Do **not** commit the generated files.

**4. Deploy Firestore Security Rules**

```bash
firebase deploy --only firestore:rules
```

**5. Install Cloud Functions dependencies**

```bash
cd functions
npm install
cd ..
```

**6. Set Cloud Function secrets in Firebase Secret Manager**

```bash
firebase functions:secrets:set RESEND_API_KEY
firebase functions:secrets:set AUTHENTICA_API_KEY
firebase functions:secrets:set GEMINI_API_KEY
```

**7. Deploy Cloud Functions**

```bash
firebase deploy --only functions
```

**8. Run the application**

```bash
# List available devices
flutter devices

# Run on a specific device
flutter run -d <device_id>
```

**9. (Optional) Start the Firebase emulator**

```bash
firebase emulators:start --only functions
```

---

## Project Structure

```
govchat/
├── lib/
│   ├── main.dart                        # App entry point, ScreenUtil + Provider init
│   ├── firebase_options.dart            # Generated Firebase config (gitignored)
│   ├── l10n/                            # ARB localization files + generated Dart
│   │   ├── app_en.arb
│   │   └── app_ar.arb
│   ├── models/                          # Shared data models (fromJson / toJson)
│   ├── auth/                            # Login, access request, change password
│   │   └── controllers/
│   ├── core/
│   │   ├── constants/                   # AppSizes (responsive sizing)
│   │   ├── theme/                       # AppColors, dark ThemeData
│   │   ├── providers/                   # LocaleProvider
│   │   ├── services/
│   │   │   ├── session_manager.dart     # Role validation, logout, inactivity
│   │   │   ├── activity_log_service.dart
│   │   │   ├── logging_service.dart
│   │   │   └── encryption/             # E2EE: crypto, key store, manager
│   │   ├── datasource/
│   │   │   ├── remote_data/            # FirebaseService singleton
│   │   │   └── local_data/             # PreferencesManager singleton
│   │   └── Widgets/                    # Shared form widgets
│   └── roles/
│       ├── employee/features/           # Chat, chat list, home, profile, new chat
│       ├── Admin/features/              # Requests, employees, groups, logs, profile
│       └── primary Admin/Features/      # Organizations, audit, dashboard, profile
├── functions/                           # Node.js Cloud Functions
│   ├── index.js                         # createAdminWithCode, sendAccessApprovedEmail
│   └── package.json
├── assets/
│   ├── govchat_logo.png
│   └── icons/
├── pubspec.yaml
├── analysis_options.yaml
├── l10n.yaml
└── firebase.json
```

---

## Development Standards

| Practice | Implementation |
|----------|---------------|
| **Architecture** | Feature-first folder structure; shared primitives in `core/`; no cross-feature imports |
| **State Management** | Provider + ChangeNotifier; controllers self-initialize; `dispose()` cleans all listeners |
| **Secure Coding** | No secrets in source; all privileged writes via Cloud Functions; OWASP Top 10 considered |
| **Static Analysis** | `flutter_lints` enforced; `flutter analyze` must pass with zero errors before merge |
| **Formatting** | `dart format lib test` enforced; single-line comments only where intent is non-obvious |
| **Testing** | `flutter test` for unit and widget tests; Firebase emulator for integration testing |
| **Code Reviews** | All changes reviewed before merge to `main`; feature branches merged via PRs |
| **Branching** | `main` (production) · `develop` (integration) · `feature/*` (work branches) |
| **Localization** | All user-visible strings in ARB files; `flutter gen-l10n` regenerates Dart classes |
| **Responsiveness** | All sizes via `AppSizes.*` wrappers; no raw numeric literals in UI code |

---

## Team

| Name | Role | Responsibilities |
|------|------|-----------------|
| Bassam Alhwarini | Scrum Master / Product Owner / Full Stack | Leads product vision and full-stack development strategy |
| Abdulrahman Alyousef | Full Stack Developer | Builds and integrates core backend and frontend systems |
| Mohammed Aloraini | UI/UX & Frontend | Designs intuitive interfaces and user experience flows |
| Abdullah Aloraini | QA & Testing | Ensures quality through rigorous test planning and execution |

---

## Roadmap

- [ ] **Firebase App Check** — Prevent unauthorized app access even with API keys
- [ ] **Firebase SDK Upgrade** — Migrate to firebase_core 4.x and related packages
- [ ] **Advanced Security Auditing** — Immutable, cryptographically signed audit trail with tamper detection
- [ ] **AI-Powered Moderation** — Automated flagging of policy-violating content
- [ ] **Performance Optimization** — Firestore query pagination, lazy loading, read cost reduction
- [ ] **Admin Dashboard Analytics** — Exportable reports, bulk user management
- [ ] **Monitoring and Observability** — Firebase Crashlytics and Performance Monitoring
- [ ] **CSP / Security Headers** — `Strict-Transport-Security`, `X-Frame-Options` in Next.js middleware

---

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the full contribution guide.

Quick summary:
1. Fork and create a feature branch from `develop`
2. Ensure `flutter analyze` and `flutter test` pass
3. Run `dart format lib test`
4. Open a PR against `develop`

**Never commit secrets, credentials, or Firebase configuration files.**

---

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md) for a full list of changes by version.

---

## Security

See [`SECURITY_AUDIT.md`](SECURITY_AUDIT.md) for the complete security audit report.

To report a vulnerability, contact the team directly — do not open a public GitHub issue.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>GovChat v1.0.0 &mdash; Built with Flutter and Firebase &mdash; &copy; 2026</sub>
</div>
