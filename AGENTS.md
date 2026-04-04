GovChat Agent Guide
Audience: Agentic coding assistants working in this repo.
Stack: Flutter (Dart >= 3.10), Firebase (core/auth/firestore/functions/storage), provider, flutter_screenutil, shared_preferences, google_fonts, cached_network_image, shimmer, flutter_svg.
Entry points: lib/main.dart bootstraps Firebase + PreferencesManager + ScreenUtil + darkTheme, home LoginScreen.
Lint baseline: flutter_lints via analysis_options.yaml; no custom Cursor/Copilot rules present.
**Build & Run**
- flutter pub get
- flutter run -d <device_id>
- flutter build apk --release (Android)
- flutter build ios --release (macOS with signing)
**Analyze & Format**
- flutter analyze
- dart format lib test
- For a specific file: dart format lib/path/to/file.dart
- Keep analyzer clean; add // ignore: rule only when justified and local.
**Tests**
- flutter test
- Single test: flutter test test/widget_test.dart --name "Counter increments smoke test"
- Filter by pattern: flutter test --plain-name "pattern"
**Repo Layout**
- lib/main.dart app entry; firebase_options.dart is generated.
- core/ contains constants, theme, datasource helpers, shared Widgets.
- auth/ holds login flow and controllers.
- roles/Admin/features/... holds admin UI (requests, employees, logs, profile, main shell).
- models/ for shared data types; reuse before creating new ones.
- assets declared in pubspec.yaml (assets/, assets/icons/, govchat_logo.png).
**State Management**
- Provider + ChangeNotifier for controllers (e.g., LoginController).
- Prefer ChangeNotifier over manual setState when state is shared across widgets.
- Controllers expose formKey, loading flags, error strings; reset error on success paths.
- Dispose TextEditingController or StreamSubscription if you add them to controllers.
**Theming**
- Dark theme in core/theme/ThemeData.dart; colors in App_color.dart; sizes in constants/app_size.dart.
- Respect Material3 (useMaterial3: true) and bottom nav theme settings.
- Use AppColors and AppSizes instead of raw literals for consistent design.
- Keep nav item labels uppercased to match current BottomNavigationBar styling.
**Layout & Responsiveness**
- ScreenUtilInit wraps the app; use AppSizes.* (which wrap .h/.w/.sp) for sizing.
- Favor Flexible/Expanded over fixed pixel values; avoid hardcoded magic numbers.
- Wrap main content in SafeArea when near system chrome; use SingleChildScrollView for forms.
- Maintain consistent padding via AppSizes.pw*/ph* helpers.
**Typography**
- GoogleFonts.manrope is used for most text; match weights and letterSpacing from examples.
- Prefer theme.textTheme where it fits; otherwise specify size via AppSizes.sp*.
- Keep text colors from AppColors (textTitle/textMuted/textSubtitle/buttonText/etc.).
- Avoid default system fonts unless explicitly desired.
**Navigation**
- AdminMainScreen holds BottomNavigationBar with _screens list; update both when adding tabs.
- Use Navigator push(MaterialPageRoute(...)) for new flows; keep constructors const when possible.
- For deep links/named routes, centralize definitions before adoption.
- Maintain stateful nav indices inside widgets; avoid global mutable state.
**Data & Storage**
- PreferencesManager is a singleton wrapper over shared_preferences; already initialized in main().
- Add new preference keys as constants to avoid typos; prefer scoped accessors over raw strings.
- Firebase options live in firebase_options.dart; regenerate via flutterfire if configs change.
- Place new data helpers under core/datasource or feature-specific data folders.
**Error Handling**
- Controllers keep errorMessage displayed in UI; clear it when retrying actions.
- Catch service exceptions in controllers; surface user-friendly text, not raw stack traces.
- For async actions, guard buttons with loading flags to prevent duplicate submissions.
**Loading States**
- isLoading booleans drive CircularProgressIndicator sized with AppSizes.
- Disable buttons while loading; keep accessibility by showing progress indicators.
- Use Shimmer for skeleton states where applicable.
**Forms & Validation**
- Use Form + GlobalKey (from controller) and validator callbacks; return error strings or null.
- Prefer shared widgets like core/Widgets/text_field_for_login.dart for consistent styling.
- Labels are uppercase and spaced per design; keep hint text concise.
- Focus/obscure behavior should follow InputDecorationTheme; avoid custom colors unless necessary.
**Imports**
- Order: dart sdk -> third-party packages -> project package imports -> relative imports.
- Prefer package:projects/... imports for cross-feature code; use relative imports within a feature.
- Remove unused imports; analyzer flags these.
**Naming**
- Files: snake_case.dart; Classes/Widgets: PascalCase; methods/vars: camelCase.
- Constants: prefer const + lowerCamel (unless enum-like or in AppColors/AppSizes).
- Private State classes prefixed with _; widgets ending with Screen/View/Tile/Card etc.
- Keep route-like widgets suffixed with Screen for clarity.
**Types & Null Safety**
- Use final for locals/fields where possible; prefer const constructors.
- Avoid dynamic; annotate public APIs with explicit types.
- Use nullable types judiciously; avoid ! unless validated.
- Prefer collection literals with typed generics (e.g., <Widget>[] for children lists).
**Assets & Media**
- Register new assets in pubspec.yaml under flutter/assets.
- Use Image.asset with fit + sized via AppSizes; cache remote images with cached_network_image.
- Keep icon sizes aligned with nav/button expectations; store custom icons in assets/icons/.
**Styling Components**
- Reuse ThemeData cardTheme/bottomNavigationBarTheme; keep backgrounds and borders consistent.
- Gradients: AppColors.gradientStart/gradientEnd for CTAs; avoid ad-hoc gradients.
- Borders/Radii: use AppSizes.r* and theme input borders.
**Lists & Iteration**
- For long lists use ListView.builder with proper padding and item keys.
- Keep physics appropriate (e.g., BouncingScrollPhysics for iOS-style if desired).
- Defer heavy item construction; split into sub-widgets for readability.
**Accessibility**
- Ensure tap targets >= AppSizes.h44; use Semantics for custom buttons if needed.
- Provide tooltip/semantics labels on icon-only buttons.
- Maintain contrast using AppColors palette; avoid low-contrast overlays.
**Testing Practices**
- Place tests under test/; mirror lib structure where practical.
- Import widgets via package:projects/... not relative to ../lib/ in new tests.
- Group related tests; use setUp/tearDown for shared fixtures.
- Mock external services (Firebase/shared_prefs) to keep tests offline and deterministic.
- When using ScreenUtil in tests, wrap pumpWidget with ScreenUtilInit and a MaterialApp.
**Performance**
- Mark stateless widgets const where possible; avoid rebuilding heavy trees.
- Cache expensive calculations; avoid setState in tight loops.
- Dispose controllers/streams to prevent leaks.
**Networking & Firebase**
- Wrap Firestore/Functions calls in repositories/services; keep UI unaware of raw Firebase APIs.
- Map FirebaseException codes to user-friendly strings; log details in debug builds only.
- Convert Timestamp to DateTime in data layer; keep models typed.
- Respect offline/latency by showing progress indicators and retry options.
**Logging & Debugging**
- Use debugPrint for temporary diagnostics; remove or gate behind kDebugMode.
- Avoid print spam; consider adding a small logger utility if logging grows.
- Surface errors via ScaffoldMessenger/SnackBar or inline banners instead of silent failures.
- Keep stack traces out of user-facing text.
**Security & Secrets**
- Do not commit credentials beyond generated firebase_options.dart.
- Avoid storing sensitive tokens in SharedPreferences; consider secure storage if needed.
- Validate user input before network calls; sanitize text where applicable.
- Restrict error detail in UI to avoid leaking internal info.
**Release Prep**
- Ensure assets exist before referencing; missing assets crash at load time.
- Run flutter clean && flutter pub get when SDK/channel changes cause build issues.
- For iOS/macOS, run pod install in ios/ or macos/ after podspec changes.
- Confirm signing configs and bundle identifiers before release builds.
**Git Hygiene**
- Do not commit build/ .dart_tool/ .packages outputs; keep pubspec.lock committed.
- Keep commit messages concise and descriptive; avoid amending others' commits.
- Branch naming is open; prefer feature/ or bugfix/ prefixes.
- No pre-commit hooks configured; run analyze/tests before PRs.
**Cursor/Copilot Rules**
- No .cursor/rules, .cursorrules, or .github/copilot-instructions.md found as of this guide.
**Extending Features**
- For new admin tabs, extend _screens and BottomNavigationBarItem lists in roles/Admin/features/Main/admin_main_screen.dart.
- Keep feature folders self-contained (data/widgets/view/models) to avoid cross-coupling.
- Share primitives (colors, sizes, fonts) via core/ instead of duplicating values.
- Follow existing naming and provider patterns when adding controllers.
**Commands Quick Reference**
- Install deps: flutter pub get
- Analyze: flutter analyze
- Format: dart format lib test
- Run: flutter run -d <device_id>
- Tests: flutter test or flutter test test/file.dart --name "<Test name>"
- Build release: flutter build apk --release
- Troubleshoot builds: flutter clean && flutter pub get
