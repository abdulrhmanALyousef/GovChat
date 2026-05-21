# Changelog

All notable changes to GovChat are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] — 2026-05-21

### Added

#### Flutter Mobile App (Employee)
- **End-to-End Encryption (E2EE)** — AES-256-GCM messaging with X25519 key agreement; private keys stored in `flutter_secure_storage`, never transmitted to the server
- **OTP Two-Factor Authentication** — SMS OTP via Authentica.sa for employee login and access request verification
- **Department Chat** — Real-time Firestore messaging scoped to the employee's department with typing indicators and read receipts
- **Private (1-to-1) Chat** — End-to-end encrypted direct messaging between employees
- **Org-Wide Chat** — Broadcast channel for all employees in an organization
- **AI Chat Summary** — Gemini-powered summary of unread messages via Cloud Function
- **E2EE Key Backup & Restore** — Password-protected backup of encryption keys for device migration
- **Push Notifications** — Firebase Cloud Messaging for new messages and access request events
- **Employee Reminders** — Local notification-based reminders with repeat scheduling
- **Media Sharing** — Image, video, and voice message support with org-level admin controls
- **Access Request Workflow** — Employees self-register and wait for admin approval before entering the system
- **Inactivity Session Timeout** — Automatic logout after 5 minutes of inactivity
- **Multilingual Support (AR/EN)** — Full right-to-left Arabic layout with runtime locale switching
- **Soft-Delete Messages** — Message deletion without permanent data loss

#### Next.js Web Admin Dashboard
- **Admin Dashboard** — Employee management, access request review, department group management, audit logs
- **Primary Admin Dashboard** — Organization management, cross-org audit logs, account provisioning via Cloud Functions
- **TOTP MFA** — Time-based one-time password mandatory for `primary_admin` accounts
- **httpOnly Session Cookies** — Secure, server-validated sessions replacing client-side token storage
- **Hidden Portal Route** — Admin portal accessible only via shared out-of-band access code
- **Rate Limiting** — IP-based rate limiting on portal, session, and TOTP endpoints
- **Inactivity Timeout** — Automatic session expiry after 30 minutes of inactivity
- **Announcements** — Admin can broadcast announcements to org employees
- **Media Sharing Controls** — Toggle image/video/voice permission per organization
- **Employee Approval Flow** — Review, approve, and reject access requests with automated email notification

#### Firebase / Cloud Functions
- **`createAdminWithCode`** — Provisions organization + admin user; generates temporary password; sends credentials via Resend email
- **`sendAccessApprovedEmail`** — Sends approval notification email when an employee's access request is approved
- **`sendOtp` / `verifyOtp`** — SMS OTP delivery and verification via Authentica.sa with rate limiting and TTL
- **`generateAiSummary`** — Gemini-powered chat summarization callable function
- **`deleteOrganization`** — Cascading hard-delete of an organization and all associated data

### Security

- Firestore rules hardened: cross-tenant read access eliminated across organizations, employees, messages, project groups, and announcements
- TOTP expected-code logging removed (was printing valid codes to server logs)
- Portal access code comparison logging removed
- Firebase credential files (`firebase_options.dart`, `google-services.json`, `GoogleService-Info.plist`) removed from git tracking and added to `.gitignore`
- npm postcss vulnerability resolved via `overrides` (GHSA-qx2v-qp2m-jg93)
- Full security audit completed — see `SECURITY_AUDIT.md`

### Infrastructure

- Cloud Functions region: `us-central1`, max 10 instances
- Secrets managed via Firebase Secret Manager (`RESEND_API_KEY`, `AUTHENTICA_API_KEY`, `GEMINI_API_KEY`)
- Node.js 24 runtime for Cloud Functions
- Flutter `publish_to: none` — private package registry

---

## Pre-release (Sprint iterations, 2025–2026)

Development was carried out across iterative sprints. All sprint work is consolidated into the v1.0.0 release above. Sprint branches have been merged into `main`.
