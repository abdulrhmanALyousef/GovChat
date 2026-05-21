# GovChat v1.0.0 — Release Notes

**Release Date:** 2026-05-21
**Type:** Initial Production Release

---

## What Is GovChat?

GovChat is a secure, multi-tenant communication platform built for government bodies and regulated enterprises. It provides end-to-end encrypted messaging, strict role-based access control, and a fully auditable backend — purpose-built for environments where data confidentiality and compliance are non-negotiable.

---

## What's Included in v1.0.0

### Flutter Mobile App (Employee)

The Flutter app is exclusively for **employees**. Administrators use the web dashboard.

| Feature | Description |
|---------|-------------|
| **E2EE Messaging** | AES-256-GCM encryption with X25519 key agreement. All messages encrypted before leaving the device. Keys stored in device-isolated secure storage. |
| **OTP Login** | Two-factor login via SMS OTP (Authentica.sa). Legacy employees without a phone number are supported via graceful fallback. |
| **Department Chat** | Real-time chat scoped to the employee's department. Typing indicators, read receipts, soft-delete. |
| **Private Chat** | 1-to-1 encrypted direct messages with any colleague in the same organization. |
| **Org-Wide Chat** | Broadcast channel visible to all employees in the organization. |
| **AI Summary** | Gemini-powered summary of unread messages accessible from the chat list. |
| **Media Sharing** | Images, videos, and voice messages — subject to admin-configured permissions. |
| **Reminders** | Personal task reminders with configurable repeat schedules. |
| **Key Backup** | Password-protected backup and restore of E2EE keys for device migration. |
| **Push Notifications** | Real-time alerts for new messages and access request events via FCM. |
| **Access Request** | New employees submit an access request (with OTP-verified phone) and wait for admin approval. |
| **Arabic & English** | Full bilingual support with RTL layout. Runtime locale switching. |

### Next.js Web Admin Dashboard

| Role | Capabilities |
|------|-------------|
| **Admin** | Manage employees, review access requests, manage department groups, review audit logs, configure media permissions, post announcements |
| **Primary Admin** | All admin capabilities plus: manage organizations, provision new orgs/admins via Cloud Functions, review cross-org audit logs |

Security features:
- httpOnly session cookies
- TOTP mandatory MFA for primary_admin
- Hidden portal access gate
- IP-based rate limiting
- 30-minute inactivity timeout

### Firebase / Cloud Functions

All privileged operations run exclusively inside Cloud Functions — no admin SDK credentials exist on any client.

- Email delivery via Resend
- SMS OTP via Authentica.sa
- AI summarization via Gemini
- Cascading org deletion
- Secrets stored in Firebase Secret Manager

---

## Security Highlights

- **Zero known critical or high vulnerabilities** at release
- Full security audit completed — see `SECURITY_AUDIT.md`
- Firebase credentials removed from git history
- Firestore rules enforce strict organizational data isolation
- E2EE keys never leave the device

---

## Breaking Changes

This is the first production release. No breaking changes from a prior stable version.

---

## Known Limitations

- **Firebase SDK versions:** Firebase Flutter plugins are on the v3.x major version. v4.x upgrades are planned post-release due to API migration scope.
- **App Check not enabled:** Firebase App Check is recommended but not yet deployed. See `SECURITY_AUDIT.md` recommendation R-01.
- **Web app is not a Flutter web build:** The admin dashboard is a separate Next.js app at `govchat-web/`, not a Flutter web target.
- **iOS not tested in production:** iOS builds have been configured but production App Store distribution has not been validated in this release cycle.

---

## Setup

See `README.md` for full installation and Firebase configuration instructions.

For demo/testing accounts, see the **Demo Accounts** section in `README.md`.

---

## Team

| Name | Role |
|------|------|
| Bassam Alhwarini | Scrum Master / Product Owner / Full Stack |
| Abdulrahman Alyousef | Full Stack Developer |
| Mohammed Aloraini | UI/UX & Frontend |
| Abdullah Aloraini | QA & Testing |
