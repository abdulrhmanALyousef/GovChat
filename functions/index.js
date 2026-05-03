/**
 * Firebase Cloud Functions for GovChat
 * Creates admin users with temp passwords via Resend
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
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

      const email = data.email;
      const firstName = data.firstName;
      const middleName = data.middleName || "";
      const lastName = data.lastName;
      const nationalId = data.nationalId || "";
      const orgId = data.organizationId;
      const orgName = data.organizationName || "";
      const department = data.department || "";
      const password = data.password;

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

        // 2. Save employee in users collection (pending)
        await admin.firestore()
            .collection("users").doc(uid).set({
              uid: uid,
              email: email,
              role: "employee",
              firstName: firstName,
              middleName: middleName,
              lastName: lastName,
              fullName: fullName,
              nationalId: nationalId,
              organizationId: orgId,
              organizationName: orgName,
              department: department,
              displayId: displayId,
              status: "pending",
              firstLogin: true,
              mustChangePassword: false,
              createdAt:
                admin.firestore.FieldValue.serverTimestamp(),
            });

        // 3. Save in accessRequests collection
        await admin.firestore()
            .collection("accessRequests").add({
              uid: uid,
              email: email,
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
