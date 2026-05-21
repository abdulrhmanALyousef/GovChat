# Contributing to GovChat

Thank you for your interest in GovChat. This document describes how to contribute effectively.

---

## Getting Started

1. **Fork the repository** and clone your fork locally.
2. **Set up Firebase** — run `flutterfire configure` to generate `lib/firebase_options.dart` for your own Firebase project. Never use the production project for development.
3. **Install dependencies:**
   ```bash
   flutter pub get
   cd functions && npm install && cd ..
   ```
4. **Create a feature branch** from `develop`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

---

## Development Rules

### Security

- **Never commit credentials.** API keys, secrets, Firebase configs, and `.env` files must never be committed.
- All Firebase credential files (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`) are gitignored. Keep it that way.
- All privileged operations must go through Cloud Functions. No `firebase-admin` calls from client code.
- If you add a new secret (API key, token, etc.), use Firebase Secret Manager (`defineSecret()`) in Cloud Functions — never hardcode it.

### Code Quality

- `flutter analyze` must pass with **zero errors and zero warnings** before submitting a PR.
- `dart format lib test` must be run before every commit.
- No raw literals in UI code — use `AppColors.*` and `AppSizes.*`.
- All user-visible strings go in `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`. Run `flutter gen-l10n` after any ARB change.
- Follow the **no-comments-unless-non-obvious** convention. Well-named identifiers document intent; comments document WHY, not WHAT.

### Architecture

- Keep features self-contained under `lib/roles/{role}/features/{feature}/`.
- Shared primitives belong in `lib/core/`.
- Controllers self-initialize — never call `_init()` from outside.
- Every role-protected screen must call `SessionManager.instance.ensureRole(context, allowedRoles: [...])` in `initState` via `addPostFrameCallback`.
- Dispose all `TextEditingController`s, `StreamSubscription`s, and `Timer`s in `dispose()`.

### Testing

- `flutter test` must pass for all new code.
- New Cloud Functions should be tested against the Firebase emulator before deploying.
- New Firestore rules changes should be validated with the Firestore Rules Simulator.

---

## Pull Request Process

1. Ensure `flutter analyze` and `flutter test` both pass locally.
2. Run `dart format lib test` and commit the result.
3. Open a PR against the `develop` branch (not `main`).
4. Write a clear PR description explaining:
   - What changed and why
   - Any security implications
   - How to test the change
5. At least one team member must review and approve before merge.
6. PRs to `main` are reserved for release merges only.

---

## Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code. Tagged releases only. |
| `develop` | Integration branch. All feature PRs merge here. |
| `feature/*` | Individual feature or bugfix work. |
| `hotfix/*` | Emergency production fixes branched from `main`. |

---

## Reporting Security Issues

Do **not** open a public GitHub issue for security vulnerabilities. Contact the team directly with a description of the issue, affected component, and reproduction steps. We aim to respond within 48 hours and release a patch within 7 days for critical issues.

---

## Code of Conduct

Be respectful. Constructive feedback is welcome. Personal attacks and harassment will not be tolerated.
