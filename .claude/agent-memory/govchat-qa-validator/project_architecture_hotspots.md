---
name: project-architecture-hotspots
description: Known architectural violations and security hotspots found during QA — collection access patterns, slug normalization divergence, status value inconsistencies
metadata:
  type: project
---

Critical bugs discovered during full-system QA (2026-05-15):

**Why:** These represent confirmed architectural invariant violations that must be fixed before release.

**How to apply:** Treat every item below as a required pre-release fix, not a nice-to-have.

## Confirmed Bugs

### BUG-001 — Legacy employee login is broken (CRITICAL)
`lib/auth/controllers/login_controller.dart` line 121–127:
If `phoneNumber` is empty (legacy employee), the login controller signs the user out and returns `l.employeePhoneRequired`. There is NO legacy bypass. Legacy employees cannot log in at all.
The spec requires: if phoneNumber is absent, skip OTP and proceed directly.

### BUG-002 — `accessRequests` status set to `'approved'` instead of `'active'` (HIGH)
`govchat-web/src/components/admin/RequestsPanel.tsx` line 66:
`updateDoc(doc(db, 'accessRequests', req.id), { status: 'approved' })`.
The canonical status standard is `pending / active / rejected`. Using `'approved'` in `accessRequests` is inconsistent with `employees/{uid}` which is correctly set to `'active'`. The `AccessRequestModel` type in `models.ts:52` also still declares `'approved'` as a valid status.

### BUG-003 — Approval does NOT call `sendAccessApprovedEmail` Cloud Function (HIGH)
`govchat-web/src/components/admin/RequestsPanel.tsx` `handleApprove()`: no Firebase Functions call exists. The approval email Cloud Function (`sendAccessApprovedEmail`) is never invoked from the web dashboard.

### BUG-004 — Approval OVERWRITES `phoneNumber` and `phoneVerified` (HIGH)
`govchat-web/src/components/admin/RequestsPanel.tsx` lines 71-89:
The `setDoc(..., { merge: true })` call on approval does NOT include `phoneNumber` or `phoneVerified` in the written fields. While `merge: true` would normally preserve existing fields, the fact that these fields are absent from the payload is fine in isolation — BUT the `displayId` is regenerated from `uid.substring(0,5)` again (line 82), potentially causing a different value from what `createEmployeeRequest` originally wrote if the logic differs. (This is a risk, not confirmed overwrite.)

### BUG-005 — `ActivityLogService.updateLoginActivity()` writes to `users` collection from mobile (MEDIUM)
`lib/core/services/activity_log_service.dart` line 83: called at `login_controller.dart:190` in the employee login path. This updates `users/{uid}.lastLoginAt` on every employee login — a direct write to the admin-only collection from the mobile app.

### BUG-006 — `E2eeManager._uploadPublicKey` writes to `users` collection from mobile (MEDIUM)
`lib/core/services/encryption/e2ee_manager.dart` lines 498-507: `_uploadPublicKey` tries to write to `users/{uid}` before trying `employees/{uid}`. Called from mobile for employee UIDs. This violates the invariant that mobile never writes to `users`.

### BUG-007 — `E2eeManager._getPublicKey` reads from `users` collection from mobile (MEDIUM)
`lib/core/services/encryption/e2ee_manager.dart` line 447: reads `users/{uid}` first. Called from mobile. Violates "mobile reads ONLY from employees."

### BUG-008 — `EmployeesPanel.handleRemove` sets `status: 'deleted'` — unrecognized in mobile (MEDIUM)
`govchat-web/src/components/admin/EmployeesPanel.tsx` line 106: sets `status: 'deleted'`. The `session_manager.dart` only allows `status == 'active'` — it would log the employee out, which is correct behavior. But `status: 'deleted'` is not in the canonical standard (pending/active/rejected) and is not handled in `login_controller.dart` with a specific error message — the employee would see a generic "Account is deleted" status message via `accountStatusMessage(status)`.

### BUG-009 — `_slugDepartment` divergence between Flutter and Cloud Functions (MEDIUM)
Flutter `_slugDepartment` (`login_controller.dart:269`): `replaceAll(' ', '_')` — only replaces spaces.
Cloud Function `slugDepartment` (`functions/index.js:43`): `replace(/[^a-zA-Z0-9_-]/g, '_')` — replaces all non-alphanumeric chars.
Web `slugDepartment` (`RequestsPanel.tsx:19`): same regex as Cloud Function.
For department names with special chars (e.g. "HR & Admin"), Cloud Function/web produce `hr___admin` but Flutter produces `hr_&_admin`. This causes chat message routing failures for such departments.

## OTP Flow Status
- `sendOtp` function: exists, rate-limited (60s cooldown non-login, 10/window login, 5/window others).
- `verifyOtp` function: exists, brute-force protected (5 attempts per 10-min window).
- Server-side phone verification token (`otpVerifications` collection) consumed one-time by `createEmployeeRequest`.
- OTP expiry: handled by `expiresAt` field in `otpVerifications` — checked server-side in `createEmployeeRequest`.

## Collection Access Summary (Mobile Flutter)
- `employees`: READ (login_controller, session_manager, _loadEmployeeProfile) — CORRECT
- `users`: READ in e2ee_manager lines 447, 473; WRITE in e2ee_manager line 500, activity_log_service line 83 — VIOLATION
- `organizations`: READ in request_access_controller — acceptable (not users/employees)
