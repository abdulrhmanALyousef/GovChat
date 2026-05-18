import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'GOVCHAT'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginTitle;

  /// No description provided for @secureAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure access to your organization'**
  String get secureAccessSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get emailLabel;

  /// No description provided for @enterEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get enterEmailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get passwordLabel;

  /// No description provided for @enterPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterPasswordHint;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @requestAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Request Access'**
  String get requestAccessButton;

  /// No description provided for @forgotPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordButton;

  /// No description provided for @endToEndEncrypted.
  ///
  /// In en, this message translates to:
  /// **'END-TO-END ENCRYPTED'**
  String get endToEndEncrypted;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'BACK TO LOGIN'**
  String get backToLogin;

  /// No description provided for @secureAccessBadge.
  ///
  /// In en, this message translates to:
  /// **'SECURE ACCESS'**
  String get secureAccessBadge;

  /// No description provided for @requestAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Request Access'**
  String get requestAccessTitle;

  /// No description provided for @requestAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the sovereign communications network. Your identity will be verified against national records.'**
  String get requestAccessSubtitle;

  /// No description provided for @endToEndEncryptionTitle.
  ///
  /// In en, this message translates to:
  /// **'End-to-End Encryption'**
  String get endToEndEncryptionTitle;

  /// No description provided for @endToEndEncryptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'All communications are secured with military-grade protocols.'**
  String get endToEndEncryptionSubtitle;

  /// No description provided for @complianceReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Compliance Ready'**
  String get complianceReadyTitle;

  /// No description provided for @complianceReadySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aligned with the latest data sovereignty regulations.'**
  String get complianceReadySubtitle;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'FIRST NAME'**
  String get firstNameLabel;

  /// No description provided for @middleNameOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'MIDDLE NAME (OPTIONAL)'**
  String get middleNameOptionalLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'LAST NAME'**
  String get lastNameLabel;

  /// No description provided for @emailAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL ADDRESS'**
  String get emailAddressLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@gmail.com'**
  String get emailHint;

  /// No description provided for @nationalIdLabel.
  ///
  /// In en, this message translates to:
  /// **'NATIONAL ID'**
  String get nationalIdLabel;

  /// No description provided for @organizationLabel.
  ///
  /// In en, this message translates to:
  /// **'ORGANIZATION'**
  String get organizationLabel;

  /// No description provided for @selectOrganizationHint.
  ///
  /// In en, this message translates to:
  /// **'Select Organization'**
  String get selectOrganizationHint;

  /// No description provided for @departmentLabel.
  ///
  /// In en, this message translates to:
  /// **'DEPARTMENT'**
  String get departmentLabel;

  /// No description provided for @selectDepartmentHint.
  ///
  /// In en, this message translates to:
  /// **'Select Department'**
  String get selectDepartmentHint;

  /// No description provided for @submitRequestButton.
  ///
  /// In en, this message translates to:
  /// **'Submit Request'**
  String get submitRequestButton;

  /// No description provided for @submitDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'By clicking Submit, you agree to the government\'s digital security policies and background verification protocols.'**
  String get submitDisclaimer;

  /// No description provided for @privacyPolicyLink.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY\nPOLICY'**
  String get privacyPolicyLink;

  /// No description provided for @systemStatusLink.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM\nSTATUS'**
  String get systemStatusLink;

  /// No description provided for @helpDeskLink.
  ///
  /// In en, this message translates to:
  /// **'HELP\nDESK'**
  String get helpDeskLink;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 GOVCHAT SECURITY CORE. ALL RIGHTS RESERVED.'**
  String get copyright;

  /// No description provided for @nameCannotContainNumbers.
  ///
  /// In en, this message translates to:
  /// **'Name cannot contain numbers'**
  String get nameCannotContainNumbers;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @minimumEightChars.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get minimumEightChars;

  /// No description provided for @mustContainSpecialChar.
  ///
  /// In en, this message translates to:
  /// **'Must contain at least one special character'**
  String get mustContainSpecialChar;

  /// No description provided for @changePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordTitle;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To maintain sovereign security, you must update\nyour temporary password before proceeding.'**
  String get changePasswordSubtitle;

  /// No description provided for @newPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'NEW PASSWORD'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @ruleMinChars.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get ruleMinChars;

  /// No description provided for @ruleUppercase.
  ///
  /// In en, this message translates to:
  /// **'At least 1 uppercase letter'**
  String get ruleUppercase;

  /// No description provided for @ruleLowercase.
  ///
  /// In en, this message translates to:
  /// **'At least 1 lowercase letter'**
  String get ruleLowercase;

  /// No description provided for @ruleNumber.
  ///
  /// In en, this message translates to:
  /// **'At least 1 number'**
  String get ruleNumber;

  /// No description provided for @ruleSpecialChar.
  ///
  /// In en, this message translates to:
  /// **'At least 1 special character'**
  String get ruleSpecialChar;

  /// No description provided for @updatePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePasswordButton;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get navHome;

  /// No description provided for @navAnnounce.
  ///
  /// In en, this message translates to:
  /// **'ANNOUNCE'**
  String get navAnnounce;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'CHAT'**
  String get navChat;

  /// No description provided for @navRemind.
  ///
  /// In en, this message translates to:
  /// **'REMIND'**
  String get navRemind;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get navProfile;

  /// No description provided for @navRequests.
  ///
  /// In en, this message translates to:
  /// **'REQUESTS'**
  String get navRequests;

  /// No description provided for @navEmployees.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEES'**
  String get navEmployees;

  /// No description provided for @navLogs.
  ///
  /// In en, this message translates to:
  /// **'LOGS'**
  String get navLogs;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'DASHBOARD'**
  String get navDashboard;

  /// No description provided for @navOrganizations.
  ///
  /// In en, this message translates to:
  /// **'ORGANIZATIONS'**
  String get navOrganizations;

  /// No description provided for @navAudit.
  ///
  /// In en, this message translates to:
  /// **'AUDIT'**
  String get navAudit;

  /// No description provided for @feedLabel.
  ///
  /// In en, this message translates to:
  /// **'FEED'**
  String get feedLabel;

  /// No description provided for @addPostButton.
  ///
  /// In en, this message translates to:
  /// **'ADD POST'**
  String get addPostButton;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @beFirstToShare.
  ///
  /// In en, this message translates to:
  /// **'Be the first to share something.'**
  String get beFirstToShare;

  /// No description provided for @deletePostTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get deletePostTitle;

  /// No description provided for @deletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'This post will be permanently removed. This action cannot be undone.'**
  String get deletePostConfirm;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButton;

  /// No description provided for @editMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMenuItem;

  /// No description provided for @deleteMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteMenuItem;

  /// No description provided for @likePlural.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likePlural;

  /// No description provided for @likeSingular.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get likeSingular;

  /// No description provided for @commentPlural.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentPlural;

  /// No description provided for @commentSingular.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentSingular;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @messagesLabel.
  ///
  /// In en, this message translates to:
  /// **'MESSAGES'**
  String get messagesLabel;

  /// No description provided for @signOutButton.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutButton;

  /// No description provided for @newChatButton.
  ///
  /// In en, this message translates to:
  /// **'NEW CHAT'**
  String get newChatButton;

  /// No description provided for @noConversationsYet.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get noConversationsYet;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @orgChatLabel.
  ///
  /// In en, this message translates to:
  /// **'ORG CHAT'**
  String get orgChatLabel;

  /// No description provided for @groupChatLabel.
  ///
  /// In en, this message translates to:
  /// **'GROUP CHAT'**
  String get groupChatLabel;

  /// No description provided for @privateChatLabel.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE'**
  String get privateChatLabel;

  /// No description provided for @privateChatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE CHAT'**
  String get privateChatSubtitle;

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'You will be signed out and your local session will be cleared from this device.'**
  String get signOutConfirm;

  /// No description provided for @announcementsLabel.
  ///
  /// In en, this message translates to:
  /// **'ANNOUNCEMENTS'**
  String get announcementsLabel;

  /// No description provided for @underDevelopment.
  ///
  /// In en, this message translates to:
  /// **'Under Development'**
  String get underDevelopment;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get comingSoon;

  /// No description provided for @remindersLabel.
  ///
  /// In en, this message translates to:
  /// **'REMINDERS'**
  String get remindersLabel;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @employeeInfoSection.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEE INFO'**
  String get employeeInfoSection;

  /// No description provided for @sessionControlsSection.
  ///
  /// In en, this message translates to:
  /// **'SESSION CONTROLS'**
  String get sessionControlsSection;

  /// No description provided for @endSessionDescription.
  ///
  /// In en, this message translates to:
  /// **'End your session and clear cached data from this device.'**
  String get endSessionDescription;

  /// No description provided for @organizationField.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organizationField;

  /// No description provided for @departmentField.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get departmentField;

  /// No description provided for @employeeIdField.
  ///
  /// In en, this message translates to:
  /// **'Employee ID'**
  String get employeeIdField;

  /// No description provided for @accessRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Requests'**
  String get accessRequestsTitle;

  /// No description provided for @pendingStatus.
  ///
  /// In en, this message translates to:
  /// **'PENDING'**
  String get pendingStatus;

  /// No description provided for @rejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectButton;

  /// No description provided for @acceptButton.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButton;

  /// No description provided for @noDepartmentSpecified.
  ///
  /// In en, this message translates to:
  /// **'No department specified'**
  String get noDepartmentSpecified;

  /// No description provided for @noPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'No pending requests'**
  String get noPendingRequests;

  /// No description provided for @newAccessRequestsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'New access requests will appear here.'**
  String get newAccessRequestsWillAppear;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @awaitingTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Awaiting timestamp'**
  String get awaitingTimestamp;

  /// No description provided for @employeesTitle.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesTitle;

  /// No description provided for @employeeDeactivatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Employee deactivated successfully'**
  String get employeeDeactivatedSuccess;

  /// No description provided for @employeeUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Employee updated successfully'**
  String get employeeUpdatedSuccess;

  /// No description provided for @noEmployeesYet.
  ///
  /// In en, this message translates to:
  /// **'No employees yet'**
  String get noEmployeesYet;

  /// No description provided for @approvedEmployeesWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Approved employees will appear here.'**
  String get approvedEmployeesWillAppear;

  /// No description provided for @searchByNameIdEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by name, ID or email'**
  String get searchByNameIdEmail;

  /// No description provided for @allFilter.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allFilter;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @noEmployeesMatch.
  ///
  /// In en, this message translates to:
  /// **'No employees match {query}'**
  String noEmployeesMatch(String query);

  /// No description provided for @activeStatus.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get activeStatus;

  /// No description provided for @removeEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Employee'**
  String get removeEmployeeTitle;

  /// No description provided for @removeEmployeeConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will deactivate {name}\'s account. They will immediately lose access to GovChat.'**
  String removeEmployeeConfirm(String name);

  /// No description provided for @removeButton.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeButton;

  /// No description provided for @empIdMissing.
  ///
  /// In en, this message translates to:
  /// **'EMP-ID MISSING'**
  String get empIdMissing;

  /// No description provided for @employeeInformationSection.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEE INFORMATION'**
  String get employeeInformationSection;

  /// No description provided for @organizationDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'ORGANIZATION DETAILS'**
  String get organizationDetailsSection;

  /// No description provided for @nameField.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameField;

  /// No description provided for @emailField.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailField;

  /// No description provided for @nationalIdField.
  ///
  /// In en, this message translates to:
  /// **'National ID'**
  String get nationalIdField;

  /// No description provided for @memberSinceField.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSinceField;

  /// No description provided for @editEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Employee'**
  String get editEmployeeTitle;

  /// No description provided for @loadingLatestData.
  ///
  /// In en, this message translates to:
  /// **'Loading latest data…'**
  String get loadingLatestData;

  /// No description provided for @nameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get nameFieldLabel;

  /// No description provided for @departmentFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'DEPARTMENT'**
  String get departmentFieldLabel;

  /// No description provided for @nationalIdFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'NATIONAL ID'**
  String get nationalIdFieldLabel;

  /// No description provided for @fullNameHint.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameHint;

  /// No description provided for @selectDepartmentFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Select department'**
  String get selectDepartmentFieldHint;

  /// No description provided for @nationalIdNumberHint.
  ///
  /// In en, this message translates to:
  /// **'National ID number'**
  String get nationalIdNumberHint;

  /// No description provided for @nameIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameIsRequired;

  /// No description provided for @departmentIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Department is required'**
  String get departmentIsRequired;

  /// No description provided for @nationalIdIsRequired.
  ///
  /// In en, this message translates to:
  /// **'National ID is required'**
  String get nationalIdIsRequired;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @editNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editNameTitle;

  /// No description provided for @adminSession.
  ///
  /// In en, this message translates to:
  /// **'Admin Session'**
  String get adminSession;

  /// No description provided for @adminSessionDescription.
  ///
  /// In en, this message translates to:
  /// **'Securely manage your admin account and sign out when finished.'**
  String get adminSessionDescription;

  /// No description provided for @logsTitle.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// No description provided for @primaryAdminSession.
  ///
  /// In en, this message translates to:
  /// **'Primary Admin Session'**
  String get primaryAdminSession;

  /// No description provided for @primaryAdminSessionDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage secure access for your organizations and end the session when finished.'**
  String get primaryAdminSessionDescription;

  /// No description provided for @signOutSecurelyDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign out securely and clear cached session data from this device.'**
  String get signOutSecurelyDescription;

  /// No description provided for @logoutButton.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutButton;

  /// No description provided for @confirmLogoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm Logout'**
  String get confirmLogoutTitle;

  /// No description provided for @confirmLogoutContent.
  ///
  /// In en, this message translates to:
  /// **'This will sign you out and clear your session from this device.'**
  String get confirmLogoutContent;

  /// No description provided for @logoutUppercase.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT'**
  String get logoutUppercase;

  /// No description provided for @cancelUppercase.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get cancelUppercase;

  /// No description provided for @createOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Organization'**
  String get createOrganizationTitle;

  /// No description provided for @createOrgSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up a new organization within the secure infrastructure.'**
  String get createOrgSubtitle;

  /// No description provided for @organizationInformationSection.
  ///
  /// In en, this message translates to:
  /// **'ORGANIZATION INFORMATION'**
  String get organizationInformationSection;

  /// No description provided for @organizationNameField.
  ///
  /// In en, this message translates to:
  /// **'Organization Name'**
  String get organizationNameField;

  /// No description provided for @enterOrganizationNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter organization name'**
  String get enterOrganizationNameHint;

  /// No description provided for @cityField.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityField;

  /// No description provided for @selectCityHint.
  ///
  /// In en, this message translates to:
  /// **'Select city'**
  String get selectCityHint;

  /// No description provided for @addressOptionalField.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get addressOptionalField;

  /// No description provided for @enterAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Enter address'**
  String get enterAddressHint;

  /// No description provided for @organizationDetailsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'ORGANIZATION DETAILS'**
  String get organizationDetailsSectionTitle;

  /// No description provided for @industryOptionalField.
  ///
  /// In en, this message translates to:
  /// **'Industry (optional)'**
  String get industryOptionalField;

  /// No description provided for @selectIndustryHint.
  ///
  /// In en, this message translates to:
  /// **'Select industry'**
  String get selectIndustryHint;

  /// No description provided for @numEmployeesOptionalField.
  ///
  /// In en, this message translates to:
  /// **'Number of Employees (optional)'**
  String get numEmployeesOptionalField;

  /// No description provided for @selectRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Select range'**
  String get selectRangeHint;

  /// No description provided for @adminAccountSection.
  ///
  /// In en, this message translates to:
  /// **'ADMIN ACCOUNT'**
  String get adminAccountSection;

  /// No description provided for @adminEmailField.
  ///
  /// In en, this message translates to:
  /// **'Admin Email'**
  String get adminEmailField;

  /// No description provided for @enterAdminEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter admin email'**
  String get enterAdminEmailHint;

  /// No description provided for @tempPasswordNote.
  ///
  /// In en, this message translates to:
  /// **'A temporary password will be generated and sent to the admin email. The admin will be required to change it on first login.'**
  String get tempPasswordNote;

  /// No description provided for @createOrganizationButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE ORGANIZATION'**
  String get createOrganizationButton;

  /// No description provided for @organizationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get organizationsTitle;

  /// No description provided for @createOrganizationAction.
  ///
  /// In en, this message translates to:
  /// **'CREATE ORGANIZATION'**
  String get createOrganizationAction;

  /// No description provided for @viewUpdateManage.
  ///
  /// In en, this message translates to:
  /// **'View, update, and manage organizations securely.'**
  String get viewUpdateManage;

  /// No description provided for @noOrganizationsFound.
  ///
  /// In en, this message translates to:
  /// **'No organizations found'**
  String get noOrganizationsFound;

  /// No description provided for @createFirstOrganization.
  ///
  /// In en, this message translates to:
  /// **'Create your first organization to get started.'**
  String get createFirstOrganization;

  /// No description provided for @failedToLoadEmployees.
  ///
  /// In en, this message translates to:
  /// **'Failed to load employees'**
  String get failedToLoadEmployees;

  /// No description provided for @noEmployeesInOrganization.
  ///
  /// In en, this message translates to:
  /// **'No employees in this organization.'**
  String get noEmployeesInOrganization;

  /// No description provided for @deleteOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete organization?'**
  String get deleteOrganizationTitle;

  /// No description provided for @deleteOrganizationConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will deactivate the organization and related users. Are you sure?'**
  String get deleteOrganizationConfirm;

  /// No description provided for @deleteUppercase.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteUppercase;

  /// No description provided for @editOrganizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Organization'**
  String get editOrganizationTitle;

  /// No description provided for @organizationNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Organization name'**
  String get organizationNameFieldLabel;

  /// No description provided for @cityFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityFieldLabel;

  /// No description provided for @addressFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get addressFieldLabel;

  /// No description provided for @industryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get industryFieldLabel;

  /// No description provided for @employeeRangeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee range'**
  String get employeeRangeFieldLabel;

  /// No description provided for @savingButton.
  ///
  /// In en, this message translates to:
  /// **'SAVING...'**
  String get savingButton;

  /// No description provided for @saveUppercase.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get saveUppercase;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get retryButton;

  /// No description provided for @unableToLoadOrganizations.
  ///
  /// In en, this message translates to:
  /// **'Unable to load organizations'**
  String get unableToLoadOrganizations;

  /// No description provided for @deleteEmployeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete employee?'**
  String get deleteEmployeeTitle;

  /// No description provided for @deleteEmployeeConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will deactivate the employee account and remove it from active lists.'**
  String get deleteEmployeeConfirm;

  /// No description provided for @closeButton.
  ///
  /// In en, this message translates to:
  /// **'CLOSE'**
  String get closeButton;

  /// No description provided for @editUppercase.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get editUppercase;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'PLEASE WAIT'**
  String get pleaseWait;

  /// No description provided for @unableToLoadEmployee.
  ///
  /// In en, this message translates to:
  /// **'Unable to load employee details.'**
  String get unableToLoadEmployee;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @auditTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get auditTitle;

  /// No description provided for @newPostTitle.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get newPostTitle;

  /// No description provided for @editPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPostTitle;

  /// No description provided for @whatsOnYourMind.
  ///
  /// In en, this message translates to:
  /// **'What\'s on your mind?'**
  String get whatsOnYourMind;

  /// No description provided for @addToPostLabel.
  ///
  /// In en, this message translates to:
  /// **'ADD TO POST'**
  String get addToPostLabel;

  /// No description provided for @photoCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Photo ({count}/4)'**
  String photoCountLabel(int count);

  /// No description provided for @postButton.
  ///
  /// In en, this message translates to:
  /// **'POST'**
  String get postButton;

  /// No description provided for @savePostButton.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get savePostButton;

  /// No description provided for @groupChatTitle.
  ///
  /// In en, this message translates to:
  /// **'GROUP CHAT'**
  String get groupChatTitle;

  /// No description provided for @endToEndEncryptedChannel.
  ///
  /// In en, this message translates to:
  /// **'END-TO-END ENCRYPTED CHANNEL'**
  String get endToEndEncryptedChannel;

  /// No description provided for @editMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get editMessageTitle;

  /// No description provided for @deleteMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Message'**
  String get deleteMessageTitle;

  /// No description provided for @deleteMessageConfirm.
  ///
  /// In en, this message translates to:
  /// **'This message will be permanently removed for everyone. This action cannot be undone.'**
  String get deleteMessageConfirm;

  /// No description provided for @editingMessage.
  ///
  /// In en, this message translates to:
  /// **'Editing message'**
  String get editingMessage;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeAMessage;

  /// No description provided for @editMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Edit message'**
  String get editMessageHint;

  /// No description provided for @isTypingSingle.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing'**
  String isTypingSingle(String name);

  /// No description provided for @arePeopleTyping.
  ///
  /// In en, this message translates to:
  /// **'{count} people are typing'**
  String arePeopleTyping(int count);

  /// No description provided for @newChatTitle.
  ///
  /// In en, this message translates to:
  /// **'New Chat'**
  String get newChatTitle;

  /// No description provided for @searchByEmployeeId.
  ///
  /// In en, this message translates to:
  /// **'Search by employee ID'**
  String get searchByEmployeeId;

  /// No description provided for @noEmployeesFound.
  ///
  /// In en, this message translates to:
  /// **'No employees found'**
  String get noEmployeesFound;

  /// No description provided for @postTitle.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postTitle;

  /// No description provided for @arabicLanguage.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabicLanguage;

  /// No description provided for @englishLanguage.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get englishLanguage;

  /// No description provided for @showingCachedData.
  ///
  /// In en, this message translates to:
  /// **'Showing cached data — could not sync latest values.'**
  String get showingCachedData;

  /// No description provided for @editButton.
  ///
  /// In en, this message translates to:
  /// **'EDIT'**
  String get editButton;

  /// No description provided for @deleteOrganizationButton.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteOrganizationButton;

  /// No description provided for @employeesLabel.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get employeesLabel;

  /// No description provided for @adminEmail.
  ///
  /// In en, this message translates to:
  /// **'ADMIN'**
  String get adminEmail;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'CITY'**
  String get cityLabel;

  /// No description provided for @createdLabel.
  ///
  /// In en, this message translates to:
  /// **'CREATED'**
  String get createdLabel;

  /// No description provided for @adminEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'ADMIN EMAIL'**
  String get adminEmailLabel;

  /// No description provided for @addressLabel.
  ///
  /// In en, this message translates to:
  /// **'ADDRESS'**
  String get addressLabel;

  /// No description provided for @industryLabel.
  ///
  /// In en, this message translates to:
  /// **'INDUSTRY'**
  String get industryLabel;

  /// No description provided for @employeeRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'EMPLOYEE RANGE'**
  String get employeeRangeLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get statusLabel;

  /// No description provided for @emailLabel2.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get emailLabel2;

  /// No description provided for @nationalIdLabel2.
  ///
  /// In en, this message translates to:
  /// **'NATIONAL ID'**
  String get nationalIdLabel2;

  /// No description provided for @departmentLabel2.
  ///
  /// In en, this message translates to:
  /// **'DEPARTMENT'**
  String get departmentLabel2;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Be the first!'**
  String get noCommentsYet;

  /// No description provided for @writeACommentHint.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get writeACommentHint;

  /// No description provided for @editedLabel.
  ///
  /// In en, this message translates to:
  /// **'· edited'**
  String get editedLabel;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// No description provided for @accountPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Your account is pending approval. Please wait for admin confirmation.'**
  String get accountPendingApproval;

  /// No description provided for @accessRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Your access request has been rejected.'**
  String get accessRequestRejected;

  /// No description provided for @accountIsStatus.
  ///
  /// In en, this message translates to:
  /// **'This account is {status}. Please contact support.'**
  String accountIsStatus(String status);

  /// No description provided for @organizationMismatchSignIn.
  ///
  /// In en, this message translates to:
  /// **'Organization mismatch detected. Please sign in again.'**
  String get organizationMismatchSignIn;

  /// No description provided for @unknownRoleError.
  ///
  /// In en, this message translates to:
  /// **'Unknown role: {role}'**
  String unknownRoleError(String role);

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email'**
  String get authErrorUserNotFound;

  /// No description provided for @authErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get authErrorWrongPassword;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled'**
  String get authErrorUserDisabled;

  /// No description provided for @authErrorInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authErrorInvalidCredential;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorDefault.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please try again'**
  String get authErrorDefault;

  /// No description provided for @pleaseSelectOrganization.
  ///
  /// In en, this message translates to:
  /// **'Please select an organization'**
  String get pleaseSelectOrganization;

  /// No description provided for @pleaseSelectDepartment.
  ///
  /// In en, this message translates to:
  /// **'Please select a department'**
  String get pleaseSelectDepartment;

  /// No description provided for @requestSubmittedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Request submitted! Waiting for admin approval.'**
  String get requestSubmittedSuccess;

  /// No description provided for @emailAlreadyRegistered.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered.'**
  String get emailAlreadyRegistered;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @userDataNotFound.
  ///
  /// In en, this message translates to:
  /// **'User data not found'**
  String get userDataNotFound;

  /// No description provided for @unknownRoleSimple.
  ///
  /// In en, this message translates to:
  /// **'Unknown role'**
  String get unknownRoleSimple;

  /// No description provided for @failedToUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Failed to update password'**
  String get failedToUpdatePassword;

  /// No description provided for @failedToSignOut.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign out. Check your connection and try again.'**
  String get failedToSignOut;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @accountDataMissing.
  ///
  /// In en, this message translates to:
  /// **'Account data missing. Please sign in.'**
  String get accountDataMissing;

  /// No description provided for @unauthorizedAccess.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized access.'**
  String get unauthorizedAccess;

  /// No description provided for @accountStatusMessage.
  ///
  /// In en, this message translates to:
  /// **'Account is {status}.'**
  String accountStatusMessage(String status);

  /// No description provided for @organizationMismatchDetected.
  ///
  /// In en, this message translates to:
  /// **'Organization mismatch detected.'**
  String get organizationMismatchDetected;

  /// No description provided for @sessionEndedInactivity.
  ///
  /// In en, this message translates to:
  /// **'Session ended due to inactivity.'**
  String get sessionEndedInactivity;

  /// No description provided for @requestApproved.
  ///
  /// In en, this message translates to:
  /// **'Request approved'**
  String get requestApproved;

  /// No description provided for @requestRejected.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get requestRejected;

  /// No description provided for @failedToApproveRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to approve request'**
  String get failedToApproveRequest;

  /// No description provided for @failedToRejectRequest.
  ///
  /// In en, this message translates to:
  /// **'Failed to reject request'**
  String get failedToRejectRequest;

  /// No description provided for @adminDataNotFound.
  ///
  /// In en, this message translates to:
  /// **'Admin data not found'**
  String get adminDataNotFound;

  /// No description provided for @organizationNotFoundForAdmin.
  ///
  /// In en, this message translates to:
  /// **'Organization not found for this admin account'**
  String get organizationNotFoundForAdmin;

  /// No description provided for @deptIT.
  ///
  /// In en, this message translates to:
  /// **'IT Department'**
  String get deptIT;

  /// No description provided for @deptHR.
  ///
  /// In en, this message translates to:
  /// **'HR Department'**
  String get deptHR;

  /// No description provided for @deptOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get deptOperations;

  /// No description provided for @deptSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get deptSecurity;

  /// No description provided for @deptOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get deptOther;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @imageMessage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get imageMessage;

  /// No description provided for @videoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get videoMessage;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording;

  /// No description provided for @cancelRecording.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelRecording;

  /// No description provided for @attachMedia.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachMedia;

  /// No description provided for @mediaAttachmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to message'**
  String get mediaAttachmentTitle;

  /// No description provided for @sendImageOption.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get sendImageOption;

  /// No description provided for @sendVideoOption.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get sendVideoOption;

  /// No description provided for @uploadingMedia.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploadingMedia;

  /// No description provided for @failedToUploadMedia.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload media. Please try again.'**
  String get failedToUploadMedia;

  /// No description provided for @tapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get tapToView;

  /// No description provided for @videoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Video too large (max 50 MB)'**
  String get videoTooLarge;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image too large (max 20 MB)'**
  String get imageTooLarge;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied'**
  String get microphonePermissionDenied;

  /// No description provided for @sendVoiceOption.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get sendVoiceOption;

  /// No description provided for @changePasswordButton.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordButton;

  /// No description provided for @changePasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity via OTP to update your password.'**
  String get changePasswordDescription;

  /// No description provided for @cpNoPhoneMessage.
  ///
  /// In en, this message translates to:
  /// **'Phone verification required. Please contact your administrator to add a verified phone number to your account.'**
  String get cpNoPhoneMessage;

  /// No description provided for @verificationCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Code'**
  String get verificationCodeTitle;

  /// No description provided for @verificationCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A 6-digit code has been sent to your registered email address.'**
  String get verificationCodeSubtitle;

  /// No description provided for @enterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 6-digit code'**
  String get enterCodeHint;

  /// No description provided for @verifyButton.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyButton;

  /// No description provided for @resendCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCodeButton;

  /// No description provided for @codeSentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Verification code sent to your email.'**
  String get codeSentSuccess;

  /// No description provided for @codeResent.
  ///
  /// In en, this message translates to:
  /// **'A new code has been sent to your email.'**
  String get codeResent;

  /// No description provided for @invalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Please try again.'**
  String get invalidCode;

  /// No description provided for @codeExpired.
  ///
  /// In en, this message translates to:
  /// **'Code expired. Please request a new one.'**
  String get codeExpired;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new password for your account.\nFollow the rules below.'**
  String get resetPasswordSubtitle;

  /// No description provided for @passwordUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully.'**
  String get passwordUpdatedSuccess;

  /// No description provided for @sendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending code...'**
  String get sendingCode;

  /// No description provided for @verifyingCode.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get verifyingCode;

  /// No description provided for @takePhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhotoOption;

  /// No description provided for @choosePhotoOption.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get choosePhotoOption;

  /// No description provided for @recordVideoOption.
  ///
  /// In en, this message translates to:
  /// **'Record Video'**
  String get recordVideoOption;

  /// No description provided for @chooseVideoOption.
  ///
  /// In en, this message translates to:
  /// **'Choose Video'**
  String get chooseVideoOption;

  /// No description provided for @navGroups.
  ///
  /// In en, this message translates to:
  /// **'GROUPS'**
  String get navGroups;

  /// No description provided for @deletedMessagesTitle.
  ///
  /// In en, this message translates to:
  /// **'DELETED MESSAGES'**
  String get deletedMessagesTitle;

  /// No description provided for @activityLogsTab.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get activityLogsTab;

  /// No description provided for @noDeletedMessages.
  ///
  /// In en, this message translates to:
  /// **'No deleted messages'**
  String get noDeletedMessages;

  /// No description provided for @noDeletedMessagesDesc.
  ///
  /// In en, this message translates to:
  /// **'Deleted messages will appear here for admin review.'**
  String get noDeletedMessagesDesc;

  /// No description provided for @noActivityLogs.
  ///
  /// In en, this message translates to:
  /// **'No activity logs yet'**
  String get noActivityLogs;

  /// No description provided for @senderLabel.
  ///
  /// In en, this message translates to:
  /// **'Sender'**
  String get senderLabel;

  /// No description provided for @deletedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Deleted by'**
  String get deletedByLabel;

  /// No description provided for @deletedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Deleted at'**
  String get deletedAtLabel;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationLabel;

  /// No description provided for @messageDeletedPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'This message was deleted'**
  String get messageDeletedPlaceholder;

  /// No description provided for @projectGroupsTitle.
  ///
  /// In en, this message translates to:
  /// **'Project Groups'**
  String get projectGroupsTitle;

  /// No description provided for @createGroupButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE GROUP'**
  String get createGroupButton;

  /// No description provided for @createGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Group'**
  String get createGroupTitle;

  /// No description provided for @groupNameLabel.
  ///
  /// In en, this message translates to:
  /// **'GROUP NAME'**
  String get groupNameLabel;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter group name'**
  String get groupNameHint;

  /// No description provided for @selectMembersLabel.
  ///
  /// In en, this message translates to:
  /// **'SELECT MEMBERS'**
  String get selectMembersLabel;

  /// No description provided for @groupNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Group name is required'**
  String get groupNameRequired;

  /// No description provided for @atLeastOneMember.
  ///
  /// In en, this message translates to:
  /// **'Select at least one member'**
  String get atLeastOneMember;

  /// No description provided for @noGroupsYet.
  ///
  /// In en, this message translates to:
  /// **'No groups yet'**
  String get noGroupsYet;

  /// No description provided for @noGroupsDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a project group to collaborate with selected employees.'**
  String get noGroupsDesc;

  /// No description provided for @groupCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Group created successfully'**
  String get groupCreatedSuccess;

  /// No description provided for @membersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String membersCount(int count);

  /// No description provided for @noEmployeesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No employees available'**
  String get noEmployeesAvailable;

  /// No description provided for @projectGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'PROJECT GROUP'**
  String get projectGroupLabel;

  /// No description provided for @changePasswordFromProfile.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePasswordFromProfile;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PASSWORD'**
  String get currentPasswordLabel;

  /// No description provided for @currentPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get currentPasswordHint;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Current password is required'**
  String get currentPasswordRequired;

  /// No description provided for @passwordChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully'**
  String get passwordChangedSuccess;

  /// No description provided for @wrongCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get wrongCurrentPassword;

  /// No description provided for @logLoginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get logLoginSuccess;

  /// No description provided for @logLoginFailure.
  ///
  /// In en, this message translates to:
  /// **'Login attempt failed'**
  String get logLoginFailure;

  /// No description provided for @logLogout.
  ///
  /// In en, this message translates to:
  /// **'User logged out'**
  String get logLogout;

  /// No description provided for @logPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get logPasswordChanged;

  /// No description provided for @logFirstLoginPasswordReset.
  ///
  /// In en, this message translates to:
  /// **'First-time password reset'**
  String get logFirstLoginPasswordReset;

  /// No description provided for @logAccessRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Access request submitted'**
  String get logAccessRequestSubmitted;

  /// No description provided for @logAccessRequestApproved.
  ///
  /// In en, this message translates to:
  /// **'Access request approved'**
  String get logAccessRequestApproved;

  /// No description provided for @logAccessRequestRejected.
  ///
  /// In en, this message translates to:
  /// **'Access request rejected'**
  String get logAccessRequestRejected;

  /// No description provided for @logEmployeeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Employee profile updated'**
  String get logEmployeeUpdated;

  /// No description provided for @logEmployeeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Employee account deactivated'**
  String get logEmployeeDeleted;

  /// No description provided for @logMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent'**
  String get logMessageSent;

  /// No description provided for @logMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get logMessageDeleted;

  /// No description provided for @logProjectGroupCreated.
  ///
  /// In en, this message translates to:
  /// **'Project group created'**
  String get logProjectGroupCreated;

  /// No description provided for @logGroupMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Group message sent'**
  String get logGroupMessageSent;

  /// No description provided for @logProjectGroupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Project group deleted'**
  String get logProjectGroupDeleted;

  /// No description provided for @logUnauthorizedAccess.
  ///
  /// In en, this message translates to:
  /// **'Unauthorized access attempt'**
  String get logUnauthorizedAccess;

  /// No description provided for @logAutoLogoutInactivity.
  ///
  /// In en, this message translates to:
  /// **'Auto logout due to inactivity'**
  String get logAutoLogoutInactivity;

  /// No description provided for @logRoleMisuseAttempt.
  ///
  /// In en, this message translates to:
  /// **'Role misuse attempt detected'**
  String get logRoleMisuseAttempt;

  /// No description provided for @logUnknownAction.
  ///
  /// In en, this message translates to:
  /// **'Unknown action'**
  String get logUnknownAction;

  /// No description provided for @logFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get logFilterAll;

  /// No description provided for @logFilterAuth.
  ///
  /// In en, this message translates to:
  /// **'Auth'**
  String get logFilterAuth;

  /// No description provided for @logFilterEmployee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get logFilterEmployee;

  /// No description provided for @logFilterChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get logFilterChat;

  /// No description provided for @logFilterSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get logFilterSecurity;

  /// No description provided for @logDateAll.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get logDateAll;

  /// No description provided for @logDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get logDateToday;

  /// No description provided for @logDateLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get logDateLast7Days;

  /// No description provided for @logSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, ID or action'**
  String get logSearchHint;

  /// No description provided for @logNoLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No logs found'**
  String get logNoLogsFound;

  /// No description provided for @logNoLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No activity logs yet'**
  String get logNoLogsYet;

  /// No description provided for @logActivityWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Activity within your organization will appear here.'**
  String get logActivityWillAppear;

  /// No description provided for @logLoadMore.
  ///
  /// In en, this message translates to:
  /// **'LOAD MORE'**
  String get logLoadMore;

  /// No description provided for @logPerformedBy.
  ///
  /// In en, this message translates to:
  /// **'By'**
  String get logPerformedBy;

  /// No description provided for @adminLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminLabel;

  /// No description provided for @companyGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companyGroupLabel;

  /// No description provided for @departmentGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get departmentGroupLabel;

  /// No description provided for @deleteGroupConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete group?'**
  String get deleteGroupConfirmTitle;

  /// No description provided for @deleteGroupConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This group and all its messages will be permanently deleted.'**
  String get deleteGroupConfirmMessage;

  /// No description provided for @cannotDeleteSystemGroup.
  ///
  /// In en, this message translates to:
  /// **'System groups cannot be deleted.'**
  String get cannotDeleteSystemGroup;

  /// No description provided for @auditSystemLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'System Audit Logs'**
  String get auditSystemLogsTitle;

  /// No description provided for @filtersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersLabel;

  /// No description provided for @clearFiltersButton.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFiltersButton;

  /// No description provided for @applyFiltersButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyFiltersButton;

  /// No description provided for @allOrganizationsFilter.
  ///
  /// In en, this message translates to:
  /// **'All Organizations'**
  String get allOrganizationsFilter;

  /// No description provided for @allRolesFilter.
  ///
  /// In en, this message translates to:
  /// **'All Roles'**
  String get allRolesFilter;

  /// No description provided for @allActionsFilter.
  ///
  /// In en, this message translates to:
  /// **'All Actions'**
  String get allActionsFilter;

  /// No description provided for @searchLogsHint.
  ///
  /// In en, this message translates to:
  /// **'Search email, user ID, description…'**
  String get searchLogsHint;

  /// No description provided for @noLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No audit logs found'**
  String get noLogsFound;

  /// No description provided for @noLogsFoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'No logs match your current filters.'**
  String get noLogsFoundSubtitle;

  /// No description provided for @logActionLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get logActionLogin;

  /// No description provided for @logActionLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logActionLogout;

  /// No description provided for @logActionOrgCreated.
  ///
  /// In en, this message translates to:
  /// **'Organization Created'**
  String get logActionOrgCreated;

  /// No description provided for @logActionOrgUpdated.
  ///
  /// In en, this message translates to:
  /// **'Organization Updated'**
  String get logActionOrgUpdated;

  /// No description provided for @logActionOrgDeleted.
  ///
  /// In en, this message translates to:
  /// **'Organization Deleted'**
  String get logActionOrgDeleted;

  /// No description provided for @logActionAdminCreated.
  ///
  /// In en, this message translates to:
  /// **'Admin Created'**
  String get logActionAdminCreated;

  /// No description provided for @logActionEmployeeApproved.
  ///
  /// In en, this message translates to:
  /// **'Employee Approved'**
  String get logActionEmployeeApproved;

  /// No description provided for @logActionEmployeeRejected.
  ///
  /// In en, this message translates to:
  /// **'Employee Rejected'**
  String get logActionEmployeeRejected;

  /// No description provided for @logActionEmployeeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Employee Updated'**
  String get logActionEmployeeUpdated;

  /// No description provided for @logActionEmployeeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Employee Deleted'**
  String get logActionEmployeeDeleted;

  /// No description provided for @logActionPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password Changed'**
  String get logActionPasswordChanged;

  /// No description provided for @logActionRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Request Submitted'**
  String get logActionRequestSubmitted;

  /// No description provided for @actorLabel.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get actorLabel;

  /// No description provided for @roleAdminLabel.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdminLabel;

  /// No description provided for @roleEmployeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get roleEmployeeLabel;

  /// No description provided for @rolePrimaryAdminLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary Admin'**
  String get rolePrimaryAdminLabel;

  /// No description provided for @dateFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get dateFromLabel;

  /// No description provided for @dateToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get dateToLabel;

  /// No description provided for @dateNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get dateNotSet;

  /// No description provided for @systemOverviewTitle.
  ///
  /// In en, this message translates to:
  /// **'System Overview'**
  String get systemOverviewTitle;

  /// No description provided for @totalOrganizationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get totalOrganizationsLabel;

  /// No description provided for @totalAdminsLabel.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get totalAdminsLabel;

  /// No description provided for @totalEmployeesLabel.
  ///
  /// In en, this message translates to:
  /// **'Employees'**
  String get totalEmployeesLabel;

  /// No description provided for @activeUsersLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Users (Last 7 Days)'**
  String get activeUsersLabel;

  /// No description provided for @recentActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Events (Last 7 Days)'**
  String get recentActivityLabel;

  /// No description provided for @weeklyActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity — Last 7 Days'**
  String get weeklyActivityTitle;

  /// No description provided for @failedToLoadDashboard.
  ///
  /// In en, this message translates to:
  /// **'Failed to load dashboard'**
  String get failedToLoadDashboard;

  /// No description provided for @noActivityData.
  ///
  /// In en, this message translates to:
  /// **'No activity data'**
  String get noActivityData;

  /// No description provided for @changePasswordSection.
  ///
  /// In en, this message translates to:
  /// **'CHANGE PASSWORD'**
  String get changePasswordSection;

  /// No description provided for @changePasswordCardDescription.
  ///
  /// In en, this message translates to:
  /// **'Update your account password for enhanced security.'**
  String get changePasswordCardDescription;

  /// No description provided for @currentPasswordLabelField.
  ///
  /// In en, this message translates to:
  /// **'CURRENT PASSWORD'**
  String get currentPasswordLabelField;

  /// No description provided for @newPasswordLabelProfile.
  ///
  /// In en, this message translates to:
  /// **'NEW PASSWORD'**
  String get newPasswordLabelProfile;

  /// No description provided for @newPasswordHintProfile.
  ///
  /// In en, this message translates to:
  /// **'Enter new password'**
  String get newPasswordHintProfile;

  /// No description provided for @confirmNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'CONFIRM PASSWORD'**
  String get confirmNewPasswordLabel;

  /// No description provided for @confirmNewPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPasswordHint;

  /// No description provided for @changePasswordAction.
  ///
  /// In en, this message translates to:
  /// **'CHANGE PASSWORD'**
  String get changePasswordAction;

  /// No description provided for @passwordChangedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password changed successfully.'**
  String get passwordChangedSuccessfully;

  /// No description provided for @incorrectCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect current password. Please try again.'**
  String get incorrectCurrentPassword;

  /// No description provided for @currentPasswordIsRequired.
  ///
  /// In en, this message translates to:
  /// **'Current password is required'**
  String get currentPasswordIsRequired;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownUser;

  /// No description provided for @logDescLogin.
  ///
  /// In en, this message translates to:
  /// **'User logged in'**
  String get logDescLogin;

  /// No description provided for @logDescLogout.
  ///
  /// In en, this message translates to:
  /// **'User logged out'**
  String get logDescLogout;

  /// No description provided for @logDescOrgCreated.
  ///
  /// In en, this message translates to:
  /// **'Organization created'**
  String get logDescOrgCreated;

  /// No description provided for @logDescOrgUpdated.
  ///
  /// In en, this message translates to:
  /// **'Organization updated'**
  String get logDescOrgUpdated;

  /// No description provided for @logDescOrgDeleted.
  ///
  /// In en, this message translates to:
  /// **'Organization deleted'**
  String get logDescOrgDeleted;

  /// No description provided for @logDescAdminCreated.
  ///
  /// In en, this message translates to:
  /// **'Admin account created'**
  String get logDescAdminCreated;

  /// No description provided for @logDescEmployeeApproved.
  ///
  /// In en, this message translates to:
  /// **'Employee approved'**
  String get logDescEmployeeApproved;

  /// No description provided for @logDescEmployeeRejected.
  ///
  /// In en, this message translates to:
  /// **'Employee rejected'**
  String get logDescEmployeeRejected;

  /// No description provided for @logDescEmployeeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Employee updated'**
  String get logDescEmployeeUpdated;

  /// No description provided for @logDescEmployeeDeleted.
  ///
  /// In en, this message translates to:
  /// **'Employee deleted'**
  String get logDescEmployeeDeleted;

  /// No description provided for @logDescPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get logDescPasswordChanged;

  /// No description provided for @logDescRequestSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Access request submitted'**
  String get logDescRequestSubmitted;

  /// No description provided for @noAnnouncementsDesc.
  ///
  /// In en, this message translates to:
  /// **'Official announcements from your organization will appear here.'**
  String get noAnnouncementsDesc;

  /// No description provided for @announcementPostedLabel.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get announcementPostedLabel;

  /// No description provided for @announcementExpiresLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get announcementExpiresLabel;

  /// No description provided for @announcementPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get announcementPriorityNormal;

  /// No description provided for @announcementPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get announcementPriorityHigh;

  /// No description provided for @announcementPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get announcementPriorityUrgent;

  /// No description provided for @logAnnouncementCreated.
  ///
  /// In en, this message translates to:
  /// **'Announcement created'**
  String get logAnnouncementCreated;

  /// No description provided for @logAnnouncementUpdated.
  ///
  /// In en, this message translates to:
  /// **'Announcement updated'**
  String get logAnnouncementUpdated;

  /// No description provided for @logAnnouncementDeleted.
  ///
  /// In en, this message translates to:
  /// **'Announcement deleted'**
  String get logAnnouncementDeleted;

  /// No description provided for @phoneNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'PHONE NUMBER'**
  String get phoneNumberLabel;

  /// No description provided for @phoneNumberHint.
  ///
  /// In en, this message translates to:
  /// **'0597123456'**
  String get phoneNumberHint;

  /// No description provided for @phoneNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneNumberRequired;

  /// No description provided for @phoneNumberInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Saudi mobile number (e.g. 0597123456)'**
  String get phoneNumberInvalid;

  /// No description provided for @employeePhoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have a verified phone number. Please contact your administrator.'**
  String get employeePhoneRequired;

  /// No description provided for @mobileEmployeeOnly.
  ///
  /// In en, this message translates to:
  /// **'This app is for employees only. Admins must sign in via the GovChat web dashboard.'**
  String get mobileEmployeeOnly;

  /// No description provided for @otpVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'OTP Verification'**
  String get otpVerificationTitle;

  /// No description provided for @otpVerificationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A 4-digit code has been sent to'**
  String get otpVerificationSubtitle;

  /// No description provided for @otpLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-Factor Authentication'**
  String get otpLoginTitle;

  /// No description provided for @otpLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For your security, enter the OTP sent to your registered phone.'**
  String get otpLoginSubtitle;

  /// No description provided for @otpEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter 4-digit OTP'**
  String get otpEnterCode;

  /// No description provided for @otpVerifyButton.
  ///
  /// In en, this message translates to:
  /// **'VERIFY OTP'**
  String get otpVerifyButton;

  /// No description provided for @otpResendButton.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get otpResendButton;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpSendingCode.
  ///
  /// In en, this message translates to:
  /// **'Sending OTP...'**
  String get otpSendingCode;

  /// No description provided for @otpVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get otpVerifying;

  /// No description provided for @otpInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP. Please try again.'**
  String get otpInvalidCode;

  /// No description provided for @otpExpiredCode.
  ///
  /// In en, this message translates to:
  /// **'OTP expired. Please request a new one.'**
  String get otpExpiredCode;

  /// No description provided for @otpTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please request a new code.'**
  String get otpTooManyAttempts;

  /// No description provided for @otpSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send OTP. Check your phone number and try again.'**
  String get otpSendFailed;

  /// No description provided for @otpVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed. Please try again.'**
  String get otpVerificationFailed;

  /// No description provided for @otpAttemptsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts remaining'**
  String otpAttemptsLeft(int count);

  /// No description provided for @logOtpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP sent to phone'**
  String get logOtpSent;

  /// No description provided for @logOtpVerified.
  ///
  /// In en, this message translates to:
  /// **'OTP verified successfully'**
  String get logOtpVerified;

  /// No description provided for @logOtpFailed.
  ///
  /// In en, this message translates to:
  /// **'OTP verification failed'**
  String get logOtpFailed;

  /// No description provided for @logPasswordResetViaSms.
  ///
  /// In en, this message translates to:
  /// **'Password reset via SMS OTP'**
  String get logPasswordResetViaSms;

  /// No description provided for @fpTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get fpTitle;

  /// No description provided for @fpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your registered email address. We\'ll send a one-time code to your verified phone number.'**
  String get fpSubtitle;

  /// No description provided for @fpIdentifyButton.
  ///
  /// In en, this message translates to:
  /// **'SEND OTP'**
  String get fpIdentifyButton;

  /// No description provided for @fpEmployeeNotFound.
  ///
  /// In en, this message translates to:
  /// **'No active employee account found with this email address.'**
  String get fpEmployeeNotFound;

  /// No description provided for @fpPasswordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successfully! Please sign in with your new password.'**
  String get fpPasswordResetSuccess;

  /// No description provided for @fpResetPasswordButton.
  ///
  /// In en, this message translates to:
  /// **'RESET PASSWORD'**
  String get fpResetPasswordButton;

  /// No description provided for @newReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'New Reminder'**
  String get newReminderTitle;

  /// No description provided for @editReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Reminder'**
  String get editReminderTitle;

  /// No description provided for @reminderDetailsSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'REMINDER DETAILS'**
  String get reminderDetailsSectionLabel;

  /// No description provided for @reminderTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'TITLE'**
  String get reminderTitleLabel;

  /// No description provided for @reminderTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Reminder title'**
  String get reminderTitleHint;

  /// No description provided for @reminderDescLabel.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION (OPTIONAL)'**
  String get reminderDescLabel;

  /// No description provided for @reminderDescHint.
  ///
  /// In en, this message translates to:
  /// **'Add more details…'**
  String get reminderDescHint;

  /// No description provided for @priorityLabel.
  ///
  /// In en, this message translates to:
  /// **'PRIORITY'**
  String get priorityLabel;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @scheduleSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULE'**
  String get scheduleSectionLabel;

  /// No description provided for @dueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'DUE DATE'**
  String get dueDateLabel;

  /// No description provided for @dueTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'DUE TIME'**
  String get dueTimeLabel;

  /// No description provided for @remindBeforeLabel.
  ///
  /// In en, this message translates to:
  /// **'REMIND BEFORE'**
  String get remindBeforeLabel;

  /// No description provided for @remindAtTime.
  ///
  /// In en, this message translates to:
  /// **'At time'**
  String get remindAtTime;

  /// No description provided for @remind15Min.
  ///
  /// In en, this message translates to:
  /// **'15 min'**
  String get remind15Min;

  /// No description provided for @remind1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get remind1Hour;

  /// No description provided for @remind1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get remind1Day;

  /// No description provided for @remind2Days.
  ///
  /// In en, this message translates to:
  /// **'2 days'**
  String get remind2Days;

  /// No description provided for @repeatSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'REPEAT'**
  String get repeatSectionLabel;

  /// No description provided for @repeatNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get repeatNone;

  /// No description provided for @repeatDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get repeatDaily;

  /// No description provided for @repeatWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get repeatWeekly;

  /// No description provided for @repeatMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get repeatMonthly;

  /// No description provided for @repeatCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get repeatCustom;

  /// No description provided for @repeatEveryLabel.
  ///
  /// In en, this message translates to:
  /// **'Every'**
  String get repeatEveryLabel;

  /// No description provided for @repeatDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'day(s)'**
  String get repeatDaysLabel;

  /// No description provided for @notificationSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATION'**
  String get notificationSectionLabel;

  /// No description provided for @notificationEnabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable notification'**
  String get notificationEnabledLabel;

  /// No description provided for @notificationEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'You will be notified at the scheduled time.'**
  String get notificationEnabledDesc;

  /// No description provided for @notificationDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'No notification will be sent.'**
  String get notificationDisabledDesc;

  /// No description provided for @createReminderButton.
  ///
  /// In en, this message translates to:
  /// **'CREATE REMINDER'**
  String get createReminderButton;

  /// No description provided for @deleteReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Reminder'**
  String get deleteReminderTitle;

  /// No description provided for @deleteReminderConfirm.
  ///
  /// In en, this message translates to:
  /// **'This reminder will be permanently deleted. This action cannot be undone.'**
  String get deleteReminderConfirm;

  /// No description provided for @searchRemindersHint.
  ///
  /// In en, this message translates to:
  /// **'Search reminders…'**
  String get searchRemindersHint;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get filterOverdue;

  /// No description provided for @filterCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get filterCompleted;

  /// No description provided for @filterHighPriority.
  ///
  /// In en, this message translates to:
  /// **'High Priority'**
  String get filterHighPriority;

  /// No description provided for @noRemindersYet.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet'**
  String get noRemindersYet;

  /// No description provided for @noRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first reminder.'**
  String get noRemindersDesc;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noSearchResults;

  /// No description provided for @noSearchResultsDesc.
  ///
  /// In en, this message translates to:
  /// **'Try a different search term or filter.'**
  String get noSearchResultsDesc;

  /// No description provided for @logReminderCreated.
  ///
  /// In en, this message translates to:
  /// **'Reminder created'**
  String get logReminderCreated;

  /// No description provided for @logReminderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Reminder updated'**
  String get logReminderUpdated;

  /// No description provided for @logReminderCompleted.
  ///
  /// In en, this message translates to:
  /// **'Reminder marked as completed'**
  String get logReminderCompleted;

  /// No description provided for @logReminderDeleted.
  ///
  /// In en, this message translates to:
  /// **'Reminder deleted'**
  String get logReminderDeleted;

  /// No description provided for @reminderPastDateError.
  ///
  /// In en, this message translates to:
  /// **'Due date and time must be in the future. Please select a later date or time.'**
  String get reminderPastDateError;

  /// No description provided for @mediaSharingDisabledMessage.
  ///
  /// In en, this message translates to:
  /// **'Media sharing is disabled by your organization administrator.'**
  String get mediaSharingDisabledMessage;

  /// No description provided for @logMediaSharingEnabled.
  ///
  /// In en, this message translates to:
  /// **'Media sharing enabled'**
  String get logMediaSharingEnabled;

  /// No description provided for @logMediaSharingDisabled.
  ///
  /// In en, this message translates to:
  /// **'Media sharing disabled'**
  String get logMediaSharingDisabled;

  /// No description provided for @encryptionKeySection.
  ///
  /// In en, this message translates to:
  /// **'Encryption Key Backup'**
  String get encryptionKeySection;

  /// No description provided for @encryptionKeyBackupDescription.
  ///
  /// In en, this message translates to:
  /// **'Securely back up your encryption key to restore your messages on a new device.'**
  String get encryptionKeyBackupDescription;

  /// No description provided for @backupKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Backup Key'**
  String get backupKeyButton;

  /// No description provided for @backupSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Encryption key backed up successfully'**
  String get backupSuccessMessage;

  /// No description provided for @backupFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to back up encryption key'**
  String get backupFailedMessage;

  /// No description provided for @backupKeyPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Backup Password'**
  String get backupKeyPasswordDialogTitle;

  /// No description provided for @backupKeyPasswordDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a strong password to protect your encryption key backup. You will need it to restore your messages on another device.'**
  String get backupKeyPasswordDialogDescription;

  /// No description provided for @backupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get backupPasswordHint;

  /// No description provided for @confirmBackupPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmBackupPasswordHint;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @restoreKeyPasswordDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore Encryption Key'**
  String get restoreKeyPasswordDialogTitle;

  /// No description provided for @restoreKeyPasswordDialogDescription.
  ///
  /// In en, this message translates to:
  /// **'An encryption key backup was found for your account. Enter your backup password to restore access to your messages.'**
  String get restoreKeyPasswordDialogDescription;

  /// No description provided for @restoreFailedWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get restoreFailedWrongPassword;

  /// No description provided for @restoreFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore encryption key'**
  String get restoreFailedMessage;

  /// No description provided for @skipRestoreButton.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get skipRestoreButton;

  /// No description provided for @restoreKeyButton.
  ///
  /// In en, this message translates to:
  /// **'RESTORE'**
  String get restoreKeyButton;

  /// No description provided for @notificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get notificationsLabel;

  /// No description provided for @notifNewMessage.
  ///
  /// In en, this message translates to:
  /// **'New message'**
  String get notifNewMessage;

  /// No description provided for @notifNewPrivateMessage.
  ///
  /// In en, this message translates to:
  /// **'New private message'**
  String get notifNewPrivateMessage;

  /// No description provided for @notifNewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'New Announcement'**
  String get notifNewAnnouncement;

  /// No description provided for @notifViewAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'View announcement'**
  String get notifViewAnnouncement;

  /// No description provided for @notifChatChannel.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get notifChatChannel;

  /// No description provided for @notifAnnouncementChannel.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get notifAnnouncementChannel;

  /// No description provided for @notifSystemChannel.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notifSystemChannel;

  /// No description provided for @logNotificationSent.
  ///
  /// In en, this message translates to:
  /// **'Push notification sent'**
  String get logNotificationSent;

  /// No description provided for @logNotificationOpened.
  ///
  /// In en, this message translates to:
  /// **'Notification opened'**
  String get logNotificationOpened;

  /// No description provided for @logNotificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Push notification failed'**
  String get logNotificationFailed;

  /// No description provided for @aiSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Chat Summary'**
  String get aiSummaryTitle;

  /// No description provided for @aiSummaryGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get aiSummaryGenerate;

  /// No description provided for @aiSummaryRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get aiSummaryRegenerate;

  /// No description provided for @aiSummaryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No summary yet'**
  String get aiSummaryEmptyTitle;

  /// No description provided for @aiSummaryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap Generate to create an AI-powered summary of this conversation.'**
  String get aiSummaryEmptySubtitle;

  /// No description provided for @aiSummaryGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Generate Summary'**
  String get aiSummaryGenerateButton;

  /// No description provided for @aiSummaryMainPoints.
  ///
  /// In en, this message translates to:
  /// **'Main Points'**
  String get aiSummaryMainPoints;

  /// No description provided for @aiSummaryDecisions.
  ///
  /// In en, this message translates to:
  /// **'Important Decisions'**
  String get aiSummaryDecisions;

  /// No description provided for @aiSummaryTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks & Action Items'**
  String get aiSummaryTasks;

  /// No description provided for @aiSummaryDeadlines.
  ///
  /// In en, this message translates to:
  /// **'Deadlines & Commitments'**
  String get aiSummaryDeadlines;

  /// No description provided for @aiSummaryTone.
  ///
  /// In en, this message translates to:
  /// **'Overall Tone'**
  String get aiSummaryTone;

  /// No description provided for @aiSummaryGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String aiSummaryGeneratedAt(String date);

  /// No description provided for @inboxSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'All Your Conversations'**
  String get inboxSummaryTitle;

  /// No description provided for @inboxSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered overview of all your conversations'**
  String get inboxSummarySubtitle;

  /// No description provided for @inboxSummaryGenerate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get inboxSummaryGenerate;

  /// No description provided for @inboxSummaryRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get inboxSummaryRegenerate;

  /// No description provided for @inboxSummaryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No inbox summary yet'**
  String get inboxSummaryEmptyTitle;

  /// No description provided for @inboxSummaryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap Generate to create an AI-powered summary of recent activity across all your chats.'**
  String get inboxSummaryEmptySubtitle;

  /// No description provided for @inboxSummaryGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Summarize Inbox'**
  String get inboxSummaryGenerateButton;

  /// No description provided for @inboxSummaryAnalysing.
  ///
  /// In en, this message translates to:
  /// **'Analysing conversations…'**
  String get inboxSummaryAnalysing;

  /// No description provided for @inboxSummaryHighlights.
  ///
  /// In en, this message translates to:
  /// **'Key Highlights'**
  String get inboxSummaryHighlights;

  /// No description provided for @inboxSummaryUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent & Action Required'**
  String get inboxSummaryUrgent;

  /// No description provided for @inboxSummaryDecisions.
  ///
  /// In en, this message translates to:
  /// **'Decisions Made'**
  String get inboxSummaryDecisions;

  /// No description provided for @inboxSummaryPending.
  ///
  /// In en, this message translates to:
  /// **'Pending Items'**
  String get inboxSummaryPending;

  /// No description provided for @inboxSummaryPerChat.
  ///
  /// In en, this message translates to:
  /// **'Per-Chat Breakdown'**
  String get inboxSummaryPerChat;

  /// No description provided for @inboxSummaryTrends.
  ///
  /// In en, this message translates to:
  /// **'Communication Trends'**
  String get inboxSummaryTrends;

  /// No description provided for @inboxSummaryGeneratedAt.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String inboxSummaryGeneratedAt(String date);

  /// No description provided for @splashTagline.
  ///
  /// In en, this message translates to:
  /// **'SECURE INTERNAL COMMUNICATION'**
  String get splashTagline;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboarding1Title.
  ///
  /// In en, this message translates to:
  /// **'Secure Communication'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Military-grade end-to-end encryption keeps every message private and protected.'**
  String get onboarding1Subtitle;

  /// No description provided for @onboarding2Title.
  ///
  /// In en, this message translates to:
  /// **'Team Collaboration'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Coordinate seamlessly across departments with real-time messaging and group channels.'**
  String get onboarding2Subtitle;

  /// No description provided for @onboarding3Title.
  ///
  /// In en, this message translates to:
  /// **'Stay Informed'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive critical announcements and organization-wide updates the moment they happen.'**
  String get onboarding3Subtitle;

  /// No description provided for @onboarding4Title.
  ///
  /// In en, this message translates to:
  /// **'Verified Identity'**
  String get onboarding4Title;

  /// No description provided for @onboarding4Subtitle.
  ///
  /// In en, this message translates to:
  /// **'OTP authentication ensures only authorized personnel can access the system.'**
  String get onboarding4Subtitle;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
