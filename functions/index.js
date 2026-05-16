/**
 * Firebase Cloud Functions for GovChat
 * Creates admin users with temp passwords via Resend
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const {defineSecret} = require("firebase-functions/params");
const admin = require("firebase-admin");
const {Resend} = require("resend");

// Initialize Firebase Admin
admin.initializeApp();

// Set global options
setGlobalOptions({maxInstances: 10, region: "us-central1"});

// Resend API key from Firebase Secret Manager
const resendApiKey = defineSecret("RESEND_API_KEY");

// Authentica.sa API key from Firebase Secret Manager
const authenticaApiKey = defineSecret("AUTHENTICA_API_KEY");

// Authentica.sa API base URL
const AUTHENTICA_BASE = "https://api.authentica.sa/api/v2";

// OTP rate-limiting constants
const OTP_SEND_COOLDOWN_SEC = 60;
const OTP_SEND_MAX_PER_WINDOW = 5;
const OTP_SEND_WINDOW_MIN = 10;
const OTP_VERIFY_MAX_ATTEMPTS = 5;
const OTP_VERIFY_WINDOW_MIN = 10;
const OTP_VERIFICATION_TTL_MIN = 5;

/**
 * Converts a department name to a Firestore-safe slug.
 * Must match the Flutter _slugDepartment() implementation exactly.
 * @param {string} value
 * @return {string}
 */
function slugDepartment(value) {
  if (!value || !value.trim()) return "general";
  return value.trim().replace(/[^a-zA-Z0-9_-]/g, "_").toLowerCase();
}

/**
 * Generates a random 8-digit temporary password
 * @return {string} The generated password
 */
function generateTempPassword() {
  let pwd = "";
  for (let i = 0; i < 8; i++) {
    pwd += Math.floor(Math.random() * 10).toString();
  }
  return pwd;
}

/**
 * Cloud Function: Create Admin with Temp Password
 */
exports.createAdminWithCode = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [resendApiKey],
    },
    async (request) => {
      const resend = new Resend(resendApiKey.value());
      const data = request.data;

      if (!data.email) {
        throw new HttpsError(
            "invalid-argument",
            "Email is required",
        );
      }

      if (!data.organizationName) {
        throw new HttpsError(
            "invalid-argument",
            "Organization name is required",
        );
      }

      const email = data.email;
      const orgName = data.organizationName;
      const city = data.city || "";
      const address = data.address || "";
      const industry = data.industry || "";
      const employeeRange = data.employeeRange || "";

      try {
        // 0. Check if organization name already exists
        const existingOrg = await admin.firestore()
            .collection("organizations")
            .where("name", "==", orgName)
            .limit(1)
            .get();

        if (!existingOrg.empty) {
          throw new HttpsError(
              "already-exists",
              "Organization name already exists",
          );
        }

        // 1. Generate 8-digit temp password
        const tempPassword = generateTempPassword();

        // 2. Create Firebase Auth user with this password
        let userRecord;
        try {
          userRecord = await admin.auth().createUser({
            email: email,
            password: tempPassword,
            emailVerified: false,
          });
        } catch (err) {
          console.error("Auth error:", err);
          if (err.code === "auth/email-already-exists") {
            throw new HttpsError(
                "already-exists",
                "Email already registered",
            );
          }
          if (err.code === "auth/invalid-email") {
            throw new HttpsError(
                "invalid-argument",
                "Invalid email address",
            );
          }
          throw new HttpsError("internal", err.message);
        }

        const uid = userRecord.uid;

        // 3. Save organization in Firestore
        const orgRef = await admin.firestore()
            .collection("organizations").add({
              name: orgName,
              city: city,
              address: address,
              industry: industry,
              employeeRange: employeeRange,
              adminEmail: email,
              adminUid: uid,
              status: "active",
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        const orgId = orgRef.id;

        // 4. Save user in Firestore with role: admin
        await admin.firestore()
            .collection("users").doc(uid).set({
              uid: uid,
              email: email,
              role: "admin",
              organizationId: orgId,
              organizationName: orgName,
              mustChangePassword: true,
              firstLogin: true,
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        // 5. Send email with temp password via Resend
        const html =
          "<div style=\"font-family:Arial;" +
          "max-width:500px;margin:auto;" +
          "padding:30px;background:#0F1320;" +
          "border-radius:12px;color:#fff;\">" +
          "<h2 style=\"color:#4ADE80;" +
          "text-align:center;\">GovChat</h2>" +
          "<p>Hello,</p>" +
          "<p>Your admin account has been created." +
          "</p>" +
          "<p>Use the following credentials " +
          "to sign in:</p>" +
          "<div style=\"background:#2D3449;" +
          "padding:20px;border-radius:8px;" +
          "margin:20px 0;\">" +
          "<p style=\"margin:5px 0;\">" +
          "<strong>Email:</strong> " + email +
          "</p>" +
          "<p style=\"margin:5px 0;\">" +
          "<strong>Temporary Password:</strong></p>" +
          "<div style=\"text-align:center;" +
          "margin:10px 0;\">" +
          "<span style=\"font-size:32px;" +
          "font-weight:bold;letter-spacing:8px;" +
          "color:#4ADE80;\">" +
          tempPassword + "</span>" +
          "</div></div>" +
          "<p>Please change your password " +
          "after first login.</p>" +
          "<p style=\"color:#8A95A3;" +
          "font-size:12px;\">If you did not " +
          "request this, ignore this email." +
          "</p></div>";

        console.log("Sending email to: " + email);

        const emailResult = await resend.emails.send({
          from: "GovChat <support@awlamateam.team>",
          to: [email],
          subject: "GovChat - Your Login Credentials",
          html: html,
        });

        console.log(
            "Resend response: " +
            JSON.stringify(emailResult),
        );

        if (emailResult.error) {
          console.error(
              "Resend error: " +
              JSON.stringify(emailResult.error),
          );
          return {
            success: true,
            uid: uid,
            emailSent: false,
            message: "Admin created but email failed: " +
              emailResult.error.message,
          };
        }

        console.log("Email sent OK, id: " +
          (emailResult.data ? emailResult.data.id : "none"));

        return {
          success: true,
          uid: uid,
          emailSent: true,
          message: "Admin account created." +
            " Temporary password sent to email.",
        };
      } catch (error) {
        console.error("Error: " + error.message, error);

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            error.message || "Unexpected error",
        );
      }
    },
);

/**
 * Cloud Function: Notify Admin of New Access Request
 * Sends an email to the organization admin via Resend
 */
exports.notifyAdminNewRequest = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [resendApiKey],
    },
    async (request) => {
      const resend = new Resend(resendApiKey.value());
      const data = request.data;

      if (!data.organizationId) {
        throw new HttpsError(
            "invalid-argument",
            "Organization ID is required",
        );
      }

      if (!data.employeeName || !data.employeeEmail) {
        throw new HttpsError(
            "invalid-argument",
            "Employee name and email are required",
        );
      }

      const orgId = data.organizationId;
      const employeeName = data.employeeName;
      const employeeEmail = data.employeeEmail;
      const department = data.department || "Not specified";
      const nationalId = data.nationalId || "Not provided";

      try {
        // 1. Get organization info
        const orgDoc = await admin.firestore()
            .collection("organizations").doc(orgId).get();

        if (!orgDoc.exists) {
          throw new HttpsError("not-found", "Organization not found");
        }

        const orgData = orgDoc.data();
        const adminEmail = orgData.adminEmail;
        const orgName = orgData.name;

        if (!adminEmail) {
          throw new HttpsError("not-found", "Admin email not found");
        }

        // 2. Send email to admin via Resend
        const html =
          "<div style=\"font-family:Arial;" +
          "max-width:500px;margin:auto;" +
          "padding:30px;background:#0F1320;" +
          "border-radius:12px;color:#fff;\">" +
          "<h2 style=\"color:#4ADE80;" +
          "text-align:center;\">GovChat</h2>" +
          "<h3 style=\"text-align:center;" +
          "color:#DAE2FD;\">New Access Request</h3>" +
          "<p style=\"color:#BCCBB9;\">A new employee " +
          "has requested to join your organization:</p>" +
          "<div style=\"background:#2D3449;" +
          "padding:20px;border-radius:8px;" +
          "margin:20px 0;\">" +
          "<p style=\"margin:8px 0;\">" +
          "<strong style=\"color:#94A3B8;\">Name:</strong> " +
          "<span style=\"color:#fff;\">" + employeeName +
          "</span></p>" +
          "<p style=\"margin:8px 0;\">" +
          "<strong style=\"color:#94A3B8;\">Email:</strong> " +
          "<span style=\"color:#fff;\">" + employeeEmail +
          "</span></p>" +
          "<p style=\"margin:8px 0;\">" +
          "<strong style=\"color:#94A3B8;\">Department:</strong> " +
          "<span style=\"color:#fff;\">" + department +
          "</span></p>" +
          "<p style=\"margin:8px 0;\">" +
          "<strong style=\"color:#94A3B8;\">National ID:</strong> " +
          "<span style=\"color:#fff;\">" + nationalId +
          "</span></p>" +
          "<p style=\"margin:8px 0;\">" +
          "<strong style=\"color:#94A3B8;\">Organization:</strong> " +
          "<span style=\"color:#fff;\">" + orgName +
          "</span></p>" +
          "</div>" +
          "<p style=\"color:#BCCBB9;\">Please review this request " +
          "in your GovChat admin dashboard.</p>" +
          "<p style=\"color:#8A95A3;font-size:12px;" +
          "margin-top:20px;\">This is an automated message " +
          "from GovChat.</p></div>";

        console.log("Sending access request notification to: " +
          adminEmail);

        const emailResult = await resend.emails.send({
          from: "GovChat <support@awlamateam.team>",
          to: [adminEmail],
          subject: "GovChat - New Access Request from " +
            employeeName,
          html: html,
        });

        console.log("Resend response: " +
          JSON.stringify(emailResult));

        if (emailResult.error) {
          console.error("Resend error: " +
            JSON.stringify(emailResult.error));
          return {
            success: true,
            emailSent: false,
            message: "Request saved but email failed: " +
              emailResult.error.message,
          };
        }

        return {
          success: true,
          emailSent: true,
          message: "Admin notified successfully.",
        };
      } catch (error) {
        console.error("Error: " + error.message, error);

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            error.message || "Unexpected error",
        );
      }
    },
);

/**
 * Cloud Function: Create Employee Request
 * Creates Auth account + users doc (pending) + accessRequests doc
 * Sends email notification to admin
 */
exports.createEmployeeRequest = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [resendApiKey],
    },
    async (request) => {
      const resend = new Resend(resendApiKey.value());
      const data = request.data;

      if (!data.email || !data.firstName || !data.lastName) {
        throw new HttpsError(
            "invalid-argument",
            "Email, first name and last name are required",
        );
      }
      if (!data.organizationId) {
        throw new HttpsError(
            "invalid-argument",
            "Organization ID is required",
        );
      }
      const phoneNumber = (data.phoneNumber || "").trim();
      if (!phoneNumber) {
        throw new HttpsError(
            "invalid-argument",
            "Phone number is required",
        );
      }

      const email = data.email;
      const firstName = data.firstName;
      const middleName = data.middleName || "";
      const lastName = data.lastName;
      const nationalId = data.nationalId || "";
      const orgId = data.organizationId;
      const orgName = data.organizationName || "";
      const department = data.department || "";
      const password = data.password;

      // Validate server-side that phone OTP was verified
      const phoneKey = phoneNumber.replace(/[+\s-]/g, "");
      const otpVerRef = admin.firestore()
          .collection("otpVerifications").doc(phoneKey);
      const otpVerDoc = await otpVerRef.get();

      if (!otpVerDoc.exists) {
        throw new HttpsError(
            "failed-precondition",
            "Phone not verified. Complete OTP verification first.",
        );
      }

      const otpVerData = otpVerDoc.data();
      const otpExpiresAt = otpVerData.expiresAt.toDate();
      if (new Date() > otpExpiresAt) {
        await otpVerRef.delete().catch(() => {});
        throw new HttpsError(
            "failed-precondition",
            "OTP verification expired. Please verify your phone again.",
        );
      }

      if (otpVerData.purpose !== "access_request") {
        throw new HttpsError(
            "failed-precondition",
            "Invalid OTP verification context.",
        );
      }

      // Consume the verification token (one-time use)
      await otpVerRef.delete();

      const fullName = middleName ?
        firstName + " " + middleName + " " + lastName :
        firstName + " " + lastName;

      try {
        // 1. Create Firebase Auth user
        let userRecord;
        try {
          userRecord = await admin.auth().createUser({
            email: email,
            password: password,
            displayName: fullName,
            emailVerified: false,
          });
        } catch (err) {
          if (err.code === "auth/email-already-exists") {
            throw new HttpsError(
                "already-exists",
                "This email is already registered",
            );
          }
          throw new HttpsError("internal", err.message);
        }

        const uid = userRecord.uid;

        const displayId = "EMP-" + uid.substring(0, 5).toUpperCase();

        // 2. Save employee in employees collection (pending)
        const deptId = slugDepartment(department);
        await admin.firestore()
            .collection("employees").doc(uid).set({
              uid: uid,
              email: email,
              name: fullName,
              nationalId: nationalId,
              organizationId: orgId,
              organizationName: orgName,
              department: department,
              departmentId: deptId,
              displayId: displayId,
              role: "employee",
              status: "pending",
              phoneNumber: phoneNumber,
              phoneVerified: true,
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        // 2b. Create employees/{uid} (pending) so the mobile app can show
        //     "account pending approval" immediately after sign-in attempt.
        //     The admin approval flow will update this to status: "active".
        await admin.firestore()
            .collection("employees").doc(uid).set({
              name: fullName,
              email: email,
              nationalId: nationalId,
              organizationId: orgId,
              organizationName: orgName,
              department: department,
              departmentId: "",
              displayId: displayId,
              role: "employee",
              status: "pending",
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        // 3. Save in accessRequests collection
        await admin.firestore()
            .collection("accessRequests").add({
              uid: uid,
              email: email,
              name: fullName,
              firstName: firstName,
              middleName: middleName,
              lastName: lastName,
              fullName: fullName,
              nationalId: nationalId,
              organizationId: orgId,
              organizationName: orgName,
              department: department,
              role: "employee",
              displayId: displayId,
              status: "pending",
              phoneNumber: phoneNumber,
              phoneVerified: true,
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        // 4. Get org admin and send notification + email
        const orgDoc = await admin.firestore()
            .collection("organizations").doc(orgId).get();

        if (orgDoc.exists) {
          const orgData = orgDoc.data();
          const adminEmail = orgData.adminEmail || "";
          const adminUid = orgData.adminUid || "";

          if (adminUid) {
            await admin.firestore()
                .collection("notifications").add({
                  toUid: adminUid,
                  type: "access_request",
                  title: "New Access Request",
                  body: fullName + " (" + email +
                    ") requested to join " + orgName +
                    " - " + department,
                  read: false,
                  createdAt:
                    admin.firestore.FieldValue.serverTimestamp(),
                });
          }

          if (adminEmail) {
            const html =
              "<div style=\"font-family:Arial;" +
              "max-width:500px;margin:auto;" +
              "padding:30px;background:#0F1320;" +
              "border-radius:12px;color:#fff;\">" +
              "<h2 style=\"color:#4ADE80;" +
              "text-align:center;\">GovChat</h2>" +
              "<h3 style=\"text-align:center;" +
              "color:#DAE2FD;\">New Employee Request</h3>" +
              "<div style=\"background:#2D3449;" +
              "padding:20px;border-radius:8px;" +
              "margin:20px 0;\">" +
              "<p><strong style=\"color:#94A3B8;\">Name:" +
              "</strong> " + fullName + "</p>" +
              "<p><strong style=\"color:#94A3B8;\">Email:" +
              "</strong> " + email + "</p>" +
              "<p><strong style=\"color:#94A3B8;\">" +
              "Department:</strong> " + department + "</p>" +
              "<p><strong style=\"color:#94A3B8;\">" +
              "National ID:</strong> " + nationalId +
              "</p></div>" +
              "<p style=\"color:#BCCBB9;\">Review this " +
              "request in your GovChat dashboard.</p></div>";

            try {
              await resend.emails.send({
                from: "GovChat <support@awlamateam.team>",
                to: [adminEmail],
                subject: "GovChat - New Employee Request: " +
                  fullName,
                html: html,
              });
            } catch (emailErr) {
              console.error("Email send error:", emailErr);
            }
          }
        }

        return {
          success: true,
          uid: uid,
          message: "Request submitted. Waiting for admin approval.",
        };
      } catch (error) {
        console.error("Error:", error.message, error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError(
            "internal",
            error.message || "Unexpected error",
        );
      }
    },
);

/**
 * One-time migration — safe to call multiple times.
 * 1. Backfills phoneNumber + phoneVerified from users/{uid} into
 *    employees/{uid} for records created before the architecture change.
 * 2. Normalises status 'approved' → 'active' (canonical status standard).
 *
 * Deploy and call once:
 *   firebase deploy --only functions:migrateEmployees
 *   (call via Firebase Console or any authenticated client)
 * Returns {phoneFixed, statusFixed, skipped, errors}.
 */
exports.migrateEmployees = onCall(
    {enforceAppCheck: false, invoker: "public"},
    async () => {
      const db = admin.firestore();
      const employeesSnap = await db.collection("employees").get();

      let phoneFixed = 0;
      let statusFixed = 0;
      let skipped = 0;
      const errors = [];

      for (const empDoc of employeesSnap.docs) {
        const uid = empDoc.id;
        const empData = empDoc.data();
        const updates = {};

        // 1. Backfill missing phoneNumber from users/{uid}
        if (!empData.phoneNumber || empData.phoneNumber.trim() === "") {
          try {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
              const phone = (userDoc.data().phoneNumber || "").trim();
              if (phone) {
                updates.phoneNumber = phone;
                updates.phoneVerified = true;
                phoneFixed++;
              }
            }
          } catch (err) {
            errors.push({uid, field: "phoneNumber", reason: err.message});
          }
        }

        // 2. Normalise status 'approved' → 'active'
        if (empData.status === "approved") {
          updates.status = "active";
          statusFixed++;
        }

        if (Object.keys(updates).length > 0) {
          try {
            await db.collection("employees").doc(uid).update(updates);
          } catch (err) {
            errors.push({uid, field: "update", reason: err.message});
          }
        } else {
          skipped++;
        }
      }

      return {phoneFixed, statusFixed, skipped, errors};
    },
);

/**
 * Cloud Function: Send OTP via Authentica.sa SMS
 * Rate-limited: 60 s cooldown, max 5 per 10-minute window.
 * purpose: "access_request" | "login" | "password_reset"
 */
exports.sendOtp = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [authenticaApiKey],
    },
    async (request) => {
      const data = request.data;

      if (!data.phone || !data.purpose) {
        throw new HttpsError(
            "invalid-argument",
            "phone and purpose are required",
        );
      }

      const phone = data.phone.trim();
      const purpose = data.purpose;
      const phoneKey = phone.replace(/[+\s-]/g, "");
      const now = new Date();

      // Rate limiting: purpose-namespaced to avoid login blocking resend.
      // Login: no per-send cooldown (user may retry immediately after going
      // back), but capped at 10 sends per 10-minute window.
      // Other purposes: 60-second cooldown + 5 sends per window.
      const isLogin = purpose === "login";
      const maxPerWindow = isLogin ? 10 : OTP_SEND_MAX_PER_WINDOW;
      const attemptKey = `${purpose}_${phoneKey}`;
      const attemptRef = admin.firestore()
          .collection("otpAttempts").doc(attemptKey);
      const attemptDoc = await attemptRef.get();

      if (attemptDoc.exists) {
        const att = attemptDoc.data();
        const windowStart = att.windowStart.toDate();
        const windowEnd = new Date(
            windowStart.getTime() + OTP_SEND_WINDOW_MIN * 60 * 1000);
        const lastSent = att.lastSentAt ? att.lastSentAt.toDate() : null;

        if (now < windowEnd && att.count >= maxPerWindow) {
          throw new HttpsError(
              "resource-exhausted",
              "Too many OTP requests. Please try again later.",
          );
        }

        // 60-second cooldown only for non-login purposes (resend prevention)
        if (!isLogin && lastSent) {
          const cooldownEnd = new Date(
              lastSent.getTime() + OTP_SEND_COOLDOWN_SEC * 1000);
          if (now < cooldownEnd) {
            const remainSec = Math.ceil((cooldownEnd - now) / 1000);
            throw new HttpsError(
                "resource-exhausted",
                `Please wait ${remainSec}s before requesting a new code.`,
            );
          }
        }

        if (now >= windowEnd) {
          await attemptRef.set({
            count: 1,
            windowStart: admin.firestore.Timestamp.fromDate(now),
            lastSentAt: admin.firestore.Timestamp.fromDate(now),
          });
        } else {
          await attemptRef.update({
            count: admin.firestore.FieldValue.increment(1),
            lastSentAt: admin.firestore.Timestamp.fromDate(now),
          });
        }
      } else {
        await attemptRef.set({
          count: 1,
          windowStart: admin.firestore.Timestamp.fromDate(now),
          lastSentAt: admin.firestore.Timestamp.fromDate(now),
        });
      }

      // Call Authentica.sa API (Node 24 built-in fetch)
      let response;
      try {
        response = await fetch(`${AUTHENTICA_BASE}/send-otp`, {
          method: "POST",
          headers: {
            "X-Authorization": authenticaApiKey.value(),
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: JSON.stringify({method: "sms", phone: phone}),
        });
      } catch (networkErr) {
        console.error("Authentica network error:", networkErr);
        throw new HttpsError("internal", "Failed to reach OTP service.");
      }

      let result;
      try {
        result = await response.json();
      } catch (_) {
        result = {};
      }

      if (!response.ok || result.success !== true) {
        console.error("Authentica sendOtp error:",
            response.status, JSON.stringify(result));
        throw new HttpsError(
            "internal",
            "Failed to send OTP. Please try again.",
        );
      }

      // Log the OTP send (fire-and-forget, best-effort)
      admin.firestore().collection("logs").add({
        actionType: "otp_sent",
        phone: phoneKey,
        purpose: purpose,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});

      return {success: true, message: "OTP sent successfully."};
    },
);

/**
 * Cloud Function: Verify OTP via Authentica.sa
 * Prevents brute-force with per-phone attempt tracking.
 * For purpose "access_request": writes a short-lived verification token
 * that createEmployeeRequest validates server-side.
 */
exports.verifyOtp = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [authenticaApiKey],
    },
    async (request) => {
      const data = request.data;

      if (!data.phone || !data.otp || !data.purpose) {
        throw new HttpsError(
            "invalid-argument",
            "phone, otp, and purpose are required",
        );
      }

      const phone = data.phone.trim();
      const otp = data.otp.toString().trim();
      const purpose = data.purpose;
      const uid = data.uid || null;
      const phoneKey = phone.replace(/[+\s-]/g, "");
      const now = new Date();

      // Brute-force check: verify attempts
      const verifyRef = admin.firestore()
          .collection("otpVerifyAttempts").doc(phoneKey);
      const verifyDoc = await verifyRef.get();

      if (verifyDoc.exists) {
        const vAtt = verifyDoc.data();
        const windowStart = vAtt.windowStart.toDate();
        const windowEnd = new Date(
            windowStart.getTime() + OTP_VERIFY_WINDOW_MIN * 60 * 1000);

        if (now < windowEnd && vAtt.count >= OTP_VERIFY_MAX_ATTEMPTS) {
          throw new HttpsError(
              "resource-exhausted",
              "Too many failed attempts. Please request a new OTP.",
          );
        }

        if (now >= windowEnd) {
          await verifyRef.delete().catch(() => {});
        }
      }

      // Call Authentica.sa verify API
      let response;
      try {
        response = await fetch(`${AUTHENTICA_BASE}/verify-otp`, {
          method: "POST",
          headers: {
            "X-Authorization": authenticaApiKey.value(),
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: JSON.stringify({otp: otp, phone: phone}),
        });
      } catch (networkErr) {
        console.error("Authentica network error:", networkErr);
        throw new HttpsError("internal", "Failed to reach OTP service.");
      }

      let result;
      try {
        result = await response.json();
      } catch (_) {
        result = {};
      }

      const verified = response.ok && result.status === true;

      if (!verified) {
        // Track failed attempt
        const freshDoc = await verifyRef.get();
        if (freshDoc.exists) {
          const vAtt = freshDoc.data();
          const windowStart = vAtt.windowStart.toDate();
          const windowEnd = new Date(
              windowStart.getTime() + OTP_VERIFY_WINDOW_MIN * 60 * 1000);
          if (now < windowEnd) {
            await verifyRef.update({
              count: admin.firestore.FieldValue.increment(1),
            });
          } else {
            await verifyRef.set({
              count: 1,
              windowStart: admin.firestore.Timestamp.fromDate(now),
            });
          }
        } else {
          await verifyRef.set({
            count: 1,
            windowStart: admin.firestore.Timestamp.fromDate(now),
          });
        }

        admin.firestore().collection("logs").add({
          actionType: "otp_failed",
          phone: phoneKey,
          purpose: purpose,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        }).catch(() => {});

        return {success: false, message: "Invalid or expired OTP."};
      }

      // OTP verified — clear attempt counter
      await verifyRef.delete().catch(() => {});

      // For access_request: write a short-lived server-side verification token
      // that createEmployeeRequest reads to confirm phone was verified.
      if (purpose === "access_request") {
        const expiresAt = new Date(
            now.getTime() + OTP_VERIFICATION_TTL_MIN * 60 * 1000);
        await admin.firestore()
            .collection("otpVerifications").doc(phoneKey).set({
              phone: phone,
              purpose: purpose,
              verifiedAt: admin.firestore.Timestamp.fromDate(now),
              expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
            });
      }

      // For login/password_reset: stamp lastOtpVerificationAt if uid provided
      if (uid && (purpose === "login" || purpose === "password_reset")) {
        admin.firestore().collection("employees").doc(uid).update({
          lastOtpVerificationAt: admin.firestore.Timestamp.fromDate(now),
        }).catch(() => {});
      }

      admin.firestore().collection("logs").add({
        actionType: "otp_verified",
        phone: phoneKey,
        purpose: purpose,
        uid: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});

      return {success: true, message: "OTP verified successfully."};
    },
);

/**
 * Cloud Function: Send Password Reset Verification Code
 * Generates a 6-digit code, stores it in Firestore with 10-min expiry,
 * and sends it to the employee's email via Resend.
 */
exports.sendPasswordResetCode = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [resendApiKey],
    },
    async (request) => {
      const resend = new Resend(resendApiKey.value());
      const data = request.data;

      if (!data.email) {
        throw new HttpsError(
            "invalid-argument",
            "Email is required",
        );
      }
      if (!data.uid) {
        throw new HttpsError(
            "invalid-argument",
            "UID is required",
        );
      }

      const email = data.email;
      const uid = data.uid;

      try {
        // Generate 6-digit code
        let code = "";
        for (let i = 0; i < 6; i++) {
          code += Math.floor(Math.random() * 10).toString();
        }

        // Store in Firestore with 10-minute expiry
        const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
        await admin.firestore()
            .collection("passwordResetCodes").doc(uid).set({
              code: code,
              email: email,
              uid: uid,
              expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        // Send email via Resend
        const html =
          "<div style=\"font-family:Arial;" +
          "max-width:500px;margin:auto;" +
          "padding:30px;background:#0F1320;" +
          "border-radius:12px;color:#fff;\">" +
          "<h2 style=\"color:#4ADE80;" +
          "text-align:center;\">GovChat</h2>" +
          "<h3 style=\"text-align:center;" +
          "color:#DAE2FD;\">Password Reset Code</h3>" +
          "<p style=\"color:#BCCBB9;\">Hello,</p>" +
          "<p style=\"color:#BCCBB9;\">You requested to " +
          "change your password. Use the following " +
          "verification code:</p>" +
          "<div style=\"background:#2D3449;" +
          "padding:20px;border-radius:8px;" +
          "margin:20px 0;text-align:center;\">" +
          "<span style=\"font-size:36px;" +
          "font-weight:bold;letter-spacing:12px;" +
          "color:#4ADE80;\">" + code + "</span>" +
          "</div>" +
          "<p style=\"color:#BCCBB9;\">This code expires " +
          "in <strong>10 minutes</strong>.</p>" +
          "<p style=\"color:#8A95A3;" +
          "font-size:12px;\">If you did not request this, " +
          "please ignore this email.</p></div>";

        const emailResult = await resend.emails.send({
          from: "GovChat <support@awlamateam.team>",
          to: [email],
          subject: "GovChat - Password Reset Code",
          html: html,
        });

        if (emailResult.error) {
          console.error("Resend error: " +
            JSON.stringify(emailResult.error));
          return {
            success: false,
            emailSent: false,
            message: "Failed to send email: " +
              emailResult.error.message,
          };
        }

        return {
          success: true,
          emailSent: true,
          message: "Verification code sent to email.",
        };
      } catch (error) {
        console.error("Error: " + error.message, error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError(
            "internal",
            error.message || "Unexpected error",
        );
      }
    },
);

/**
 * Cloud Function: Verify Password Reset Code
 * Validates the 6-digit code against Firestore and checks expiry.
 */
exports.verifyPasswordResetCode = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
    },
    async (request) => {
      const data = request.data;

      if (!data.uid || !data.code) {
        throw new HttpsError(
            "invalid-argument",
            "UID and code are required",
        );
      }

      const uid = data.uid;
      const code = data.code;

      try {
        const doc = await admin.firestore()
            .collection("passwordResetCodes").doc(uid).get();

        if (!doc.exists) {
          return {
            success: false,
            message: "No code found. " +
              "Please request a new one.",
          };
        }

        const docData = doc.data();

        // Check expiry
        const expiresAt = docData.expiresAt.toDate();
        if (new Date() > expiresAt) {
          await admin.firestore()
              .collection("passwordResetCodes").doc(uid).delete();
          return {
            success: false,
            message: "Code expired. " +
              "Please request a new one.",
          };
        }

        // Check code match
        if (docData.code !== code) {
          return {success: false, message: "Invalid code. Please try again."};
        }

        // Code valid — delete it so it can't be reused
        await admin.firestore()
            .collection("passwordResetCodes").doc(uid).delete();

        return {success: true, message: "Code verified."};
      } catch (error) {
        console.error("Error: " + error.message, error);
        if (error instanceof HttpsError) throw error;
        throw new HttpsError(
            "internal",
            error.message || "Unexpected error",
        );
      }
    },
);

/**
 * Cloud Function: Reset Password With OTP
 * Uses Firebase Admin SDK to update the password after confirming that
 * verifyOtp already stamped lastOtpVerificationAt within the last 10 minutes.
 * The OTP timestamp is deleted after use to prevent replay.
 */
exports.resetPasswordWithOtp = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
    },
    async (request) => {
      const data = request.data;

      if (!data.uid || !data.newPassword) {
        throw new HttpsError(
            "invalid-argument",
            "uid and newPassword are required",
        );
      }

      const uid = data.uid;
      const newPassword = data.newPassword;

      if (typeof newPassword !== "string" || newPassword.length < 8) {
        throw new HttpsError(
            "invalid-argument",
            "Password must be at least 8 characters",
        );
      }

      // Verify employee exists and is active
      const empRef = admin.firestore().collection("employees").doc(uid);
      const empDoc = await empRef.get();

      if (!empDoc.exists) {
        throw new HttpsError("not-found", "Employee not found");
      }

      const empData = empDoc.data();

      if (empData.status !== "active") {
        throw new HttpsError("permission-denied", "Account is not active");
      }

      // Verify recent OTP — lastOtpVerificationAt must be within 10 minutes
      const lastOtpAt = empData.lastOtpVerificationAt ?
          empData.lastOtpVerificationAt.toDate() :
          null;

      const now = new Date();
      const OTP_VALIDITY_MS = 10 * 60 * 1000;

      if (!lastOtpAt || (now - lastOtpAt) > OTP_VALIDITY_MS) {
        throw new HttpsError(
            "failed-precondition",
            "OTP verification has expired. Please request a new code.",
        );
      }

      // Update password via Admin SDK (no recent-login requirement)
      await admin.auth().updateUser(uid, {password: newPassword});

      // Delete the OTP timestamp so it cannot be reused
      await empRef.update({
        lastOtpVerificationAt: admin.firestore.FieldValue.delete(),
      });

      // Audit log — fire-and-forget
      admin.firestore().collection("logs").add({
        actionType: "password_reset_completed",
        uid: uid,
        email: empData.email || "",
        organizationId: empData.organizationId || "",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }).catch(() => {});

      return {success: true, message: "Password reset successfully."};
    },
);

/**
 * Cloud Function: Send Access Approval Email
 */
exports.sendAccessApprovedEmail = onCall(
    {
      enforceAppCheck: false,
      cors: true,
      invoker: "public",
      secrets: [resendApiKey],
    },
    async (request) => {
      const resend = new Resend(resendApiKey.value());
      const data = request.data;

      const email = data.email;
      const name = data.name || "there";

      if (!email) {
        throw new HttpsError(
            "invalid-argument",
            "Email is required",
        );
      }

      try {
        console.log("sendAccessApprovedEmail -> sending to", email);
        const html =
          "<div style=\"font-family:Arial;" +
          "max-width:500px;margin:auto;" +
          "padding:30px;background:#0F1320;" +
          "border-radius:12px;color:#fff;\">" +
          "<h2 style=\"color:#4ADE80;" +
          "text-align:center;\">GovChat</h2>" +
          "<h3 style=\"text-align:center;" +
          "color:#DAE2FD;\">Access Approved</h3>" +
          "<p style=\"color:#BCCBB9;\">Hello " + name + ",</p>" +
          "<p style=\"color:#BCCBB9;\">Your request has been approved. " +
          "You can now log in to GovChat.</p>" +
          "<div style=\"background:#2D3449;" +
          "padding:18px;border-radius:8px;" +
          "margin:18px 0;\">" +
          "<p style=\"margin:8px 0;color:#DAE2FD;\">Email: " + email + "</p>" +
          "<p style=\"margin:8px 0;color:#DAE2FD;\">Status: Approved</p>" +
          "</div>" +
          "<p style=\"color:#8A95A3;" +
          "font-size:12px;\">If you did not request this, " +
          "please ignore this email.</p>" +
          "</div>";

        const result = await resend.emails.send({
          from: "GovChat <support@awlamateam.team>",
          to: [email],
          subject: "GovChat - Access Approved",
          html: html,
        });

        if (result.error) {
          console.error("Resend error: " + JSON.stringify(result.error));
          return {
            success: true,
            emailSent: false,
            message: "Approval saved but email failed: " + result.error.message,
          };
        }

        console.log("sendAccessApprovedEmail -> email sent", result.data);
        return {
          success: true,
          emailSent: true,
          message: "Approval email sent successfully.",
        };
      } catch (error) {
        console.error("Approval email error: " + error.message, error);

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            error.message || "Unexpected error",
        );
      }
    },
);

// ─────────────────────────────────────────────────────────────────────────────
// PUSH NOTIFICATION HELPERS
// ─────────────────────────────────────────────────────────────────────────────

const FCM_COLOR = "#4ADE80";

/**
 * Send an FCM multicast message to up to 500 tokens per batch.
 * Automatically removes stale tokens (registration-not-registered) from
 * Firestore after a failed send.
 *
 * @param {string[]} tokens FCM registration tokens
 * @param {object} payload FCM message payload (tokens key added internally)
 * @param {Map} tokenToUid token to UID map for stale-token cleanup
 * @return {Promise<void>}
 */
async function sendFcmMulticast(tokens, payload, tokenToUid) {
  const chunks = [];
  for (let i = 0; i < tokens.length; i += 500) {
    chunks.push(tokens.slice(i, i + 500));
  }
  for (const chunk of chunks) {
    try {
      const msg = Object.assign({}, payload, {tokens: chunk});
      const response = await admin.messaging().sendEachForMulticast(msg);

      // Remove stale/invalid tokens from Firestore
      const cleanups = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errObj = resp.error || {};
          const code = errObj.code || "";
          if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
          ) {
            const uid = tokenToUid && tokenToUid.get(chunk[idx]);
            if (uid) {
              cleanups.push(
                  admin.firestore().collection("employees").doc(uid)
                      .update({
                        fcmToken: admin.firestore.FieldValue.delete(),
                      })
                      .catch(() => {}),
              );
            }
          }
        }
      });
      if (cleanups.length) await Promise.all(cleanups);
    } catch (err) {
      console.error("[FCM] sendEachForMulticast error:", err.message);
    }
  }
}

/**
 * Standard Android + APNS overrides merged into the FCM payload.
 * @param {object} payload Base FCM payload object (mutated and returned)
 * @param {string} channelId Android notification channel ID
 * @return {object} Payload with platform-specific config merged in
 */
function withPlatformConfig(payload, channelId) {
  payload.android = {
    priority: "high",
    notification: {channelId: channelId, color: FCM_COLOR, priority: "high"},
  };
  payload.apns = {payload: {aps: {sound: "default", badge: 1}}};
  return payload;
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT NOTIFICATION TRIGGERS
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Department chat - notify all department members except the sender.
 * Path: organizations/{orgId}/departments/{deptId}/messages/{msgId}
 */
exports.onDeptChatMessageCreated = onDocumentCreated(
    {
      document:
        "organizations/{orgId}/departments/{deptId}/messages/{msgId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      const data = snapshot && snapshot.data();
      if (!data || data.isDeleted) return;

      const orgId = event.params.orgId;
      const deptId = event.params.deptId;
      const senderUid = data.senderUid || "";
      const senderId = data.senderId || "Unknown";
      const conversationPath =
        "organizations/" + orgId + "/departments/" + deptId + "/messages";

      let senderName = senderId;
      if (senderUid) {
        const doc = await admin.firestore()
            .collection("employees").doc(senderUid).get();
        if (doc.exists) {
          const docData = doc.data();
          senderName = (docData && docData.name) || senderId;
        }
      }

      const snap = await admin.firestore()
          .collection("employees")
          .where("organizationId", "==", orgId)
          .where("departmentId", "==", deptId)
          .where("status", "==", "active")
          .get();

      const tokenToUid = new Map();
      snap.docs
          .filter((doc) => doc.id !== senderUid)
          .forEach((doc) => {
            const token = doc.data().fcmToken;
            if (token) tokenToUid.set(token, doc.id);
          });

      if (tokenToUid.size === 0) return;

      await sendFcmMulticast(
          Array.from(tokenToUid.keys()),
          withPlatformConfig({
            notification: {title: senderName, body: "New message"},
            data: {
              type: "chat",
              conversationPath: conversationPath,
              chatName: deptId,
              senderDisplayId: senderId,
              senderName: senderName,
              organizationId: orgId,
            },
          }, "govchat_messages"),
          tokenToUid,
      );
    },
);

/**
 * Private (1-to-1) chat - notify the other participant.
 * Path: organizations/{orgId}/private_chats/{chatId}/messages/{msgId}
 */
exports.onPrivateChatMessageCreated = onDocumentCreated(
    {
      document:
        "organizations/{orgId}/private_chats/{chatId}/messages/{msgId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      const data = snapshot && snapshot.data();
      if (!data || data.isDeleted) return;

      const orgId = event.params.orgId;
      const chatId = event.params.chatId;
      const senderUid = data.senderUid || "";
      const senderId = data.senderId || "Unknown";
      const conversationPath =
        "organizations/" + orgId + "/private_chats/" + chatId + "/messages";

      // Resolve other participant from the chat doc
      const chatDoc = await admin.firestore()
          .collection("organizations").doc(orgId)
          .collection("private_chats").doc(chatId).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data() || {};
      const participants = chatData.participants || [];
      const recipientUid = participants.find((u) => u !== senderUid);
      if (!recipientUid) return;

      const recipientDoc = await admin.firestore()
          .collection("employees").doc(recipientUid).get();
      if (!recipientDoc.exists) return;

      const recipientData = recipientDoc.data() || {};
      const token = recipientData.fcmToken;
      if (!token) return;

      let senderName = senderId;
      if (senderUid) {
        const doc = await admin.firestore()
            .collection("employees").doc(senderUid).get();
        if (doc.exists) {
          const docData = doc.data();
          senderName = (docData && docData.name) || senderId;
        }
      }

      const tokenToUid = new Map([[token, recipientUid]]);
      await sendFcmMulticast(
          [token],
          withPlatformConfig({
            notification: {title: senderName, body: "New private message"},
            data: {
              type: "chat",
              conversationPath: conversationPath,
              chatName: "Private",
              senderDisplayId: senderId,
              senderName: senderName,
              organizationId: orgId,
            },
          }, "govchat_messages"),
          tokenToUid,
      );
    },
);

/**
 * Organization-wide chat - notify all org employees except the sender.
 * Path: organizations/{orgId}/org_chats/{chatId}/messages/{msgId}
 */
exports.onOrgChatMessageCreated = onDocumentCreated(
    {
      document:
        "organizations/{orgId}/org_chats/{chatId}/messages/{msgId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      const data = snapshot && snapshot.data();
      if (!data || data.isDeleted) return;

      const orgId = event.params.orgId;
      const chatId = event.params.chatId;
      const senderUid = data.senderUid || "";
      const senderId = data.senderId || "Unknown";
      const conversationPath =
        "organizations/" + orgId + "/org_chats/" + chatId + "/messages";

      let senderName = senderId;
      if (senderUid) {
        const doc = await admin.firestore()
            .collection("employees").doc(senderUid).get();
        if (doc.exists) {
          const docData = doc.data();
          senderName = (docData && docData.name) || senderId;
        }
      }

      const snap = await admin.firestore()
          .collection("employees")
          .where("organizationId", "==", orgId)
          .where("status", "==", "active")
          .get();

      const tokenToUid = new Map();
      snap.docs
          .filter((doc) => doc.id !== senderUid)
          .forEach((doc) => {
            const token = doc.data().fcmToken;
            if (token) tokenToUid.set(token, doc.id);
          });

      if (tokenToUid.size === 0) return;

      const orgDoc = await admin.firestore()
          .collection("organizations").doc(orgId).get();
      const orgDocData = orgDoc.exists && orgDoc.data();
      const chatName = (orgDocData && orgDocData.name) || "Org Chat";

      await sendFcmMulticast(
          Array.from(tokenToUid.keys()),
          withPlatformConfig({
            notification: {title: senderName, body: "New message in org chat"},
            data: {
              type: "chat",
              conversationPath: conversationPath,
              chatName: chatName,
              senderDisplayId: senderId,
              senderName: senderName,
              organizationId: orgId,
            },
          }, "govchat_messages"),
          tokenToUid,
      );
    },
);

/**
 * Project group chat - notify all group members except the sender.
 * Path: projectGroups/{groupId}/messages/{msgId}
 */
exports.onGroupChatMessageCreated = onDocumentCreated(
    {
      document: "projectGroups/{groupId}/messages/{msgId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      const data = snapshot && snapshot.data();
      if (!data || data.isDeleted) return;

      const groupId = event.params.groupId;
      const senderUid = data.senderUid || "";
      const senderId = data.senderId || "Unknown";
      const conversationPath = "projectGroups/" + groupId + "/messages";

      const groupDoc = await admin.firestore()
          .collection("projectGroups").doc(groupId).get();
      if (!groupDoc.exists) return;

      const groupData = groupDoc.data() || {};
      const memberIds = groupData.memberIds || [];
      const groupName = groupData.name || "Group";
      const orgId = groupData.organizationId || "";

      let senderName = senderId;
      if (senderUid) {
        const doc = await admin.firestore()
            .collection("employees").doc(senderUid).get();
        if (doc.exists) {
          const docData = doc.data();
          senderName = (docData && docData.name) || senderId;
        }
      }

      const recipientUids = memberIds.filter((uid) => uid !== senderUid);
      if (recipientUids.length === 0) return;

      const empDocs = await Promise.all(
          recipientUids.map((uid) =>
            admin.firestore().collection("employees").doc(uid).get(),
          ),
      );

      const tokenToUid = new Map();
      empDocs.forEach((doc) => {
        if (doc.exists) {
          const d = doc.data() || {};
          const token = d.fcmToken;
          if (token) tokenToUid.set(token, doc.id);
        }
      });

      if (tokenToUid.size === 0) return;

      await sendFcmMulticast(
          Array.from(tokenToUid.keys()),
          withPlatformConfig({
            notification: {
              title: senderName + " · " + groupName,
              body: "New message",
            },
            data: {
              type: "chat",
              conversationPath: conversationPath,
              chatName: groupName,
              senderDisplayId: senderId,
              senderName: senderName,
              organizationId: orgId,
            },
          }, "govchat_messages"),
          tokenToUid,
      );
    },
);

// ─────────────────────────────────────────────────────────────────────────────
// ANNOUNCEMENT NOTIFICATION TRIGGER
// ─────────────────────────────────────────────────────────────────────────────

/**
 * New announcement - notify all active employees in the organization.
 * Path: announcements/{announcementId}
 */
exports.onAnnouncementCreated = onDocumentCreated(
    {
      document: "announcements/{announcementId}",
      region: "asia-east1",
    },
    async (event) => {
      const snapshot = event.data;
      const data = snapshot && snapshot.data();
      if (!data || data.isActive === false) return;

      const orgId = data.organizationId || "";
      if (!orgId) return;

      const announcementId = event.params.announcementId;
      const title = data.title || "New Announcement";
      const preview = typeof data.content === "string" ?
        data.content.substring(0, 120) : "";

      const snap = await admin.firestore()
          .collection("employees")
          .where("organizationId", "==", orgId)
          .where("status", "==", "active")
          .get();

      const tokenToUid = new Map();
      snap.docs.forEach((doc) => {
        const token = doc.data().fcmToken;
        if (token) tokenToUid.set(token, doc.id);
      });

      if (tokenToUid.size === 0) return;

      await sendFcmMulticast(
          Array.from(tokenToUid.keys()),
          withPlatformConfig({
            notification: {title: title, body: preview || "View announcement"},
            data: {
              type: "announcement",
              announcementId: announcementId,
              organizationId: orgId,
            },
          }, "govchat_announcements"),
          tokenToUid,
      );

      console.log(
          "[FCM] announcement " + announcementId +
          " sent to " + tokenToUid.size + " employees in org " + orgId,
      );
    },
);
