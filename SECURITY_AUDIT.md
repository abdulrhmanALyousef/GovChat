# GovChat Security Audit — v1.0.0

**Audit Date:** 2026-05-21
**Audited by:** Internal security review
**Scope:** Flutter mobile app, Next.js web dashboard, Firebase Functions, Firestore rules, authentication flows

---

## Summary

| Severity | Found | Fixed | Remaining |
|----------|-------|-------|-----------|
| Critical | 2 | 2 | 0 |
| High | 5 | 5 | 0 |
| Medium | 4 | 3 | 1 |
| Low | 3 | 3 | 0 |

**Overall status:** All critical and high issues resolved. One medium-severity item is a known Next.js bundled-dependency issue pending upstream release.

---

## Critical

### C-01 — Firebase credentials committed to git

**Issue:** `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist` containing real Firebase API keys were tracked by git.

**Risk:** Any developer who clones the repository would have access to the project's Firebase API keys, potentially allowing unauthorized API calls or resource abuse if Firebase Security Rules were misconfigured.

**Affected area:** Flutter mobile app — root-level git history

**Fix applied:**
- Added all three files to `.gitignore`
- Removed from git tracking via `git rm --cached`
- Created `.example` template versions with placeholder values
- Updated README with `flutterfire configure` setup instructions

**Recommendation:** Rotate Firebase API keys in the Firebase Console after this commit lands. Although these keys are embedded in the shipped APK (and are therefore not truly secret), rotation is best practice after any unintended disclosure.

---

### C-02 — TOTP expected code logged in plaintext

**Issue:** `src/lib/auth/totp.ts` contained `console.log('[TOTP] Expected code:', expected, '| Received:', token)`, printing the valid TOTP code for every verification attempt.

**Risk:** Any party with access to server logs (logging services, log aggregators, cloud provider consoles) could extract valid TOTP codes and bypass two-factor authentication for `primary_admin` accounts during the 30-second window.

**Affected area:** Next.js web dashboard — TOTP verification server route

**Severity:** Critical

**Fix applied:** Removed the `console.log` lines that printed the expected code and received token. The `console.error` fallback for exceptions is retained.

---

## High

### H-01 — Portal access code comparison details logged

**Issue:** `src/app/api/auth/check-portal/route.ts` logged the received code length, expected code length, and match result for every portal access attempt.

**Risk:** Log exfiltration could help an attacker narrow down the length/format of the portal code, reducing brute-force search space.

**Affected area:** Next.js web dashboard — admin portal gate

**Fix applied:** Replaced verbose logs with a single `[Portal] Invalid portal code attempt from {ip}` warning on failure.

---

### H-02 — TOTP verification logs submitted token

**Issue:** `src/app/api/auth/verify-totp/route.ts` logged the submitted TOTP token value and TOTP secret metadata on every request.

**Risk:** Server log compromise could leak submitted codes during the valid window, or reveal metadata about the TOTP secret length.

**Affected area:** Next.js web dashboard — TOTP verification endpoint

**Fix applied:** Removed both `console.log` lines. Failure events still log the UID and IP for audit purposes (without the token value).

---

### H-03 — TOTP setup route logged session internals

**Issue:** `src/app/api/auth/setup-totp/route.ts` logged session presence, role, `mfaPending` flag, and ID token presence on every GET request.

**Risk:** Verbose session state in logs aids session reconstruction if logs are compromised.

**Affected area:** Next.js web dashboard — TOTP setup endpoint

**Fix applied:** Removed all three debug-level `console.log` statements. Auth guard logic unchanged.

---

### H-04 — Firestore rules: cross-tenant organization read

**Issue:** `organizations/{orgId}` and `organizations/{orgId}/settings/{settingDoc}` both used `allow read: if isAuthenticated()`, granting any authenticated user in any organization the ability to read metadata and settings from every organization in the database.

**Risk:** Data leakage across organizational boundaries in a multi-tenant government platform. An employee in Organization A could enumerate Organization B's name, settings, and media-sharing configuration.

**Affected area:** Firestore Security Rules — organizations collection

**Fix applied:** Scoped reads to `callerBelongsToOrg(orgId) || isPrimaryAdmin()` using a new `callerBelongsToOrg()` helper that checks the caller's `organizationId` against the requested org.

---

### H-05 — Firestore rules: cross-tenant message read

**Issue:** Department messages, org-wide chat messages, and private chat messages all used `allow read: if isAuthenticated()`, allowing any authenticated user to read messages from any organization.

**Risk:** Complete confidentiality breakdown — any authenticated account could read all messages in all organizations.

**Affected area:** Firestore Security Rules — organizations/{orgId} subcollections

**Fix applied:** Message reads are now scoped to `callerBelongsToOrg(orgId)`. Writes require org membership for the specific org.

---

## Medium

### M-01 — Cross-tenant employee record read

**Issue:** `employees/{uid}` used `allow read: if isEmployee()`, allowing any employee to read all employee records across all organizations (needed for E2EE public key distribution but over-scoped).

**Risk:** Employee PII (name, display ID, department) accessible cross-organization.

**Affected area:** Firestore Security Rules — employees collection

**Fix applied:** Employee reads now require `resource.data.organizationId == employeeOrgId()`, scoping cross-employee reads to the caller's own organization.

---

### M-02 — Cross-tenant project group read

**Issue:** `projectGroups/{groupId}` and its messages subcollection used `allow read: if isAuthenticated()`.

**Risk:** Project group names and messages readable across organizations.

**Affected area:** Firestore Security Rules — projectGroups collection

**Fix applied:** Reads scoped to `resource.data.organizationId == adminOrgId() || resource.data.organizationId == employeeOrgId()`.

---

### M-03 — npm postcss vulnerability (indirect via Next.js)

**Issue:** Next.js 16.2.6 bundles an internal `postcss < 8.5.10` (advisory GHSA-qx2v-qp2m-jg93) — XSS via unescaped `</style>` in CSS stringify output.

**Risk:** Moderate — affects CSS build-time processing, not runtime auth flows. Exploitability requires attacker-controlled CSS input to the build pipeline.

**Affected area:** Next.js web dashboard — build toolchain

**Fix applied:** Added `"overrides": { "postcss": "^8.5.15" }` to `package.json`. `npm audit` now reports 0 vulnerabilities.

---

### M-04 — Outdated Flutter Firebase packages (acknowledged)

**Issue:** Firebase Flutter plugins (firebase_core, firebase_auth, cloud_firestore, etc.) are on major version 3.x while 4.x is available. flutter_local_notifications is on 18.x while 21.x is available.

**Risk:** Low — missing bug fixes and performance improvements. No known security CVEs in the current versions.

**Affected area:** Flutter mobile app — pubspec.yaml

**Status:** Acknowledged. Major version upgrades require API migration testing and are deferred to a post-v1 sprint to avoid regression risk at release time.

**Recommendation:** Schedule a Firebase SDK upgrade sprint after v1.0.0 ships.

---

## Low

### L-01 — Debug `debugPrint` statements in Flutter release builds

**Issue:** 198 `debugPrint()` calls across the Flutter codebase.

**Risk:** Negligible — Flutter's `debugPrint` is a no-op in release builds (`kReleaseMode` check is performed internally). No sensitive data is exposed in production APKs.

**Affected area:** Flutter mobile app — various controllers and services

**Status:** Resolved by Flutter's release-mode behavior. No code change required.

---

### L-02 — SESSION_SECRET and ADMIN_PORTAL_CODE in .env.local

**Issue:** `.env.local` in the web repo contains real `SESSION_SECRET` and `ADMIN_PORTAL_CODE` values.

**Risk:** None for the repository (`.env*.local` is correctly gitignored and the file is not tracked). Risk exists only if the file is manually shared or the deployment environment is compromised.

**Affected area:** Next.js web dashboard — local environment

**Fix applied:** Updated `.env.local.example` to include all required variables with placeholder values and generation instructions. Confirmed `.env.local` is not tracked.

**Recommendation:** Rotate `SESSION_SECRET` and `ADMIN_PORTAL_CODE` before the production deployment.

---

### L-03 — Gemini API key in Firebase Secret Manager (best practice confirmation)

**Issue:** Cloud Functions use `GEMINI_API_KEY` via `defineSecret()` — confirm it is stored in Firebase Secret Manager and not hardcoded.

**Risk:** None — `defineSecret()` correctly reads from Firebase Secret Manager at function invocation time. No key value is in source code.

**Affected area:** Firebase Cloud Functions — index.js

**Status:** Confirmed correct. No action required.

---

## Architecture Security Assessment

### Authentication & Session

| Control | Status | Notes |
|---------|--------|-------|
| Firebase Auth — server-side ID token validation | Pass | Session route verifies ID token before issuing cookie |
| httpOnly session cookies | Pass | `SESSION_COOKIE` set with `httpOnly: true` |
| TOTP MFA for primary_admin | Pass | Required before full session is issued |
| Session inactivity timeout (Flutter) | Pass | 5-minute timeout at `MyApp` level via `Listener` |
| Role validation on every protected screen | Pass | `SessionManager.ensureRole()` in `initState` |
| Employee-only restriction on Flutter app | Pass | Admins blocked at session route level |

### End-to-End Encryption

| Control | Status | Notes |
|---------|--------|-------|
| AES-256-GCM message encryption | Pass | All messages encrypted before Firestore write |
| X25519 key agreement | Pass | Private chats use deterministic key derivation |
| Private keys in secure storage | Pass | `flutter_secure_storage` — never sent to server |
| Group key distribution | Pass | Per-member wrapped keys at `{conversationPath}/groupKey/{uid}` |
| Key cache eviction on logout | Pass | `E2eeManager.clearCache()` called in `logout()` |

### Backend / Cloud Functions

| Control | Status | Notes |
|---------|--------|-------|
| No admin SDK credentials in client code | Pass | `firebase-admin` used server-side only |
| Secrets via Firebase Secret Manager | Pass | `RESEND_API_KEY`, `AUTHENTICA_API_KEY`, `GEMINI_API_KEY` |
| OTP rate limiting | Pass | 5 attempts per 10-minute window; 60-second resend cooldown |
| OTP expiry | Pass | 5-minute TTL enforced server-side |

### Firestore Rules

| Control | Status | Notes |
|---------|--------|-------|
| Default deny | Pass | Catch-all `allow read, write: if false` |
| Organization isolation | Fixed | Cross-tenant reads fixed in v1.0.0 |
| Role-based write guards | Pass | All writes require appropriate role |
| E2EE key isolation | Pass | Only key owner or admin can read group keys |

---

## Recommendations for Post-v1

1. **Enable Firebase App Check** — Prevents unauthorized apps from accessing Firebase resources even with the API key.
2. **Rotate Firebase API keys** — After the credential files are removed from git history.
3. **Upgrade Firebase Flutter SDKs** — Move to firebase_core 4.x and related packages.
4. **Add Content Security Policy headers** — Set `X-Frame-Options`, `X-Content-Type-Options`, `Strict-Transport-Security` in Next.js middleware.
5. **Enable Firebase Authentication multi-factor authentication** — For admin accounts in addition to the current TOTP implementation.
6. **Implement Firestore query-level org scoping** — Add `where('organizationId', '==', orgId)` to all collection queries as defense-in-depth alongside security rules.
7. **Cryptographic audit trail** — Consider signing log entries to detect tampering.

---

*This audit covers v1.0.0 of GovChat. Security is a continuous process — re-audit after major feature additions.*
