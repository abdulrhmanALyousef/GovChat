# GovChat — Agent Reference

A secure, Firebase-backed government communication platform.
Roles: `primary_admin`, `admin`, `employee`.

---

## Project Rules

- State management: `provider` (ChangeNotifier only). No Riverpod, Bloc, or GetX.
- UI: `google_fonts` (Manrope), `flutter_screenutil`. All sizes via `AppSizes`, all colors via `AppColors`.
- No `context.mounted` checks are skipped after any `await`.
- Firebase access always goes through `FirebaseService.instance` (auth, firestore) or direct SDK singletons (`FirebaseStorage.instance`).
- Navigation: `Navigator.push` / `Navigator.pushAndRemoveUntil` only. No named routes.
- File naming: `snake_case.dart`. Class naming: `PascalCase`.
- Controllers live in `features/<name>/controller/` beside their screen.
- Models live in `lib/models/`.

---

## Firestore Schema

### `users/{uid}`
Role-agnostic auth record used by SessionManager.
```
uid, email, role, status, firstLogin, mustChangePassword,
organizationId?, organizationName?, createdAt
```

### `organizations/{orgId}`
```
name, city, address?, industry?, employeeRange?, createdAt
```

### `organizations/{orgId}/org_chats/general`
Organization-wide general chat document. Holds the `typing` map (same shape as department chat).

### `organizations/{orgId}/org_chats/general/messages/{msgId}`
Organization-wide general chat messages. Shared across every employee in the organization.
```
text, senderId, createdAt, isEdited, status (map), deletedAt?
```

### `organizations/{orgId}/departments/{deptId}/messages/{msgId}`
Department group-chat messages.
```
text, senderId, createdAt, isEdited, status (map), deletedAt?
```

### `organizations/{orgId}/private_chats/{chatId}`
```
participants: [uid, uid], participantNames: {uid: name}
```

### `organizations/{orgId}/private_chats/{chatId}/messages/{msgId}`
Same schema as department messages.

### `employees/{employeeId}`
Employee profile document (mirrors `users/{uid}` for employees).
```
name, email, nationalId, organizationId, organizationName,
department, departmentId, displayId, status, createdAt
```

### `employees/{employeeId}/posts/{postId}`
Employee social-feed posts. Queried via `collectionGroup('posts')`.
```
employeeId          String   — UID of the owning employee
text                String   — Post body text
mediaUrls           [String] — Firebase Storage download URLs (0–4 images)
createdAt           Timestamp
createdByDisplayId  String   — e.g. "EMP-XXXXX" — used for ownership checks
createdByName       String
likes               Int      — default 0
commentsCount       Int      — default 0
likedBy             [String] — display-IDs of employees who liked the post
```
**No index required** — collection-group query has no `orderBy`; sorted client-side.

### `employees/{employeeId}/posts/{postId}/comments/{commentId}`
```
text                String
createdAt           Timestamp
createdByDisplayId  String
createdByName       String
```

---

## Models

| Model | File | Key fields |
|---|---|---|
| `AdminModel` | `lib/models/admin_model.dart` | uid, email, role, organizationId, firstLogin, mustChangePassword |
| `EmployeeModel` | `lib/models/employee_model.dart` | id, name, email, nationalId, organizationId, organizationName, department, departmentId, displayId, status |
| `ConversationModel` | `lib/models/conversation_model.dart` | id, name, type (`'organization'`\|`'department'`\|`'private'`), lastMessage, lastMessageTime, organizationId, departmentId |
| `ChatMessage` | `lib/models/chat_message.dart` | id, text, senderId, createdAt, isEdited, status |
| `PostModel` | `lib/models/post_model.dart` | id, employeeId, text, mediaUrls, createdAt, createdByDisplayId, createdByName, likes, commentsCount, likedBy + `copyWith()` |
| `CommentModel` | `lib/models/comment_model.dart` | id, text, createdAt, createdByDisplayId, createdByName |

---

## Routing (Login → Destination)

| Role | Destination |
|---|---|
| `primary_admin` | `MainScreen` |
| `admin` | `AdminMainScreen` |
| `employee` | `EmployeeMainScreen(employee)` |

Password-rotation screens intercept before destination for `admin`/`primary_admin`.

---

## Employee Role — Screen Map

`EmployeeMainScreen` is the shell with a 5-tab `BottomNavigationBar`.
**Uses `IndexedStack`** — all tab widgets stay alive across tab switches so their
`ChangeNotifierProvider` controllers (e.g. `PostController`) are never recreated.

| Index | Label | Screen | Status |
|---|---|---|---|
| 0 | HOME | `HomeScreen` | Live — post feed + create/edit/delete |
| 1 | ANNOUNCE | `AnnounceScreen` | Under development |
| 2 | CHAT | `ChatListScreen` | Live — org general + department + private chats |
| 3 | REMIND | `RemindScreen` | Under development |
| 4 | PROFILE | `EmployeeProfileScreen` | Live — employee info + logout |

---

## Organization-Wide General Chat

All employees in the same organization share a single general chat, separate from and independent of department chats.

### Firestore paths

| Path | Purpose |
|---|---|
| `organizations/{orgId}/org_chats/general` | Chat document — holds the `typing` map |
| `organizations/{orgId}/org_chats/general/messages/{msgId}` | Messages subcollection |

Message schema is identical to department messages: `text, senderId, createdAt, isEdited, status (map), deletedAt?`.

### ConversationModel — type `'organization'`

`messagesCollectionPath` returns `organizations/{orgId}/org_chats/general/messages` when `type == 'organization'`.

### ChatListController (`features/chat_list/controller/chat_list_controller.dart`)

- `_addOrganizationChat()` — called first in `_init()`. Inserts a `ConversationModel(type:'organization', id:'org_general')` into `_convMap` and subscribes to its last-message stream. Chat name defaults to `employee.organizationName` or `'General Chat'`.
- `_rebuildList()` — all conversation types (org, department, private) sorted together by `lastMessageTime` descending. Conversations with no messages yet sink to the bottom. No type has a fixed pinned position.
- Private chat `name` is set to the other participant's `displayId` (from `participantDisplayIds` map in the Firestore doc), **not** their full name.

### ChatListScreen UI (`features/chat_list/chat_list_screen.dart`)

| Element | Org value |
|---|---|
| `_ConversationAvatar` icon | `Icons.corporate_fare_outlined` |
| `_ConversationTypeBadge` label | `'ORG CHAT'` |
| AppBar subtitle on open | `'ORG CHAT'` |

### Navigation flow

`_ConversationTile._openChat()` detects `type == 'organization'` and opens the existing `EmployeeChatScreen` with:
- `chatTitle` = `conversation.name` (org name)
- `chatSubtitle` = `'ORG CHAT'`
- `messagesPath` = `conversation.messagesCollectionPath`

The existing `ChatController` derives the typing-indicator document reference by dropping the last path segment from `messagesPath`, yielding `organizations/{orgId}/org_chats/general` — no controller changes required.

---

## Post Feed Feature

### Upload contract (write side)

The Firestore post document is **never written until every image upload
has completed successfully** and returned a valid download URL.

1. `putFile(file)` is awaited — returns a `TaskSnapshot`.
2. `snapshot.state == TaskState.success` is verified explicitly.
3. `getDownloadURL()` is called **only after** confirming step 2.
4. If any image fails, all already-uploaded files in the batch are deleted
   (rollback) and the method rethrows — no Firestore write happens.

### Feed contract (read side — flash-and-disappear fix)

**Why posts flashed and disappeared:** `collectionGroup('posts').orderBy('createdAt', descending: true)` has two fatal interactions:

1. **Missing collection-group index.** The query requires a manually created index in Firebase Console. Without it the SDK serves from local cache first (post appears briefly), then the server query fails → `onError` fires → feed shows error state → post disappears.

2. **`FieldValue.serverTimestamp()` on pending writes.** Firestore resolves `createdAt` to `null` while the server write is pending. An `orderBy` query silently excludes documents with a null ordered field, so the post is in local cache but excluded from the ordered query results until the server confirms the write.

**Fix applied in `PostController._init()`:**

- `orderBy` is removed from the Firestore query entirely → no index required, no null-exclusion.
- `.snapshots(includeMetadataChanges: true)` is used so the stream fires when `hasPendingWrites` transitions from `true` to `false`.
- Documents with `doc.metadata.hasPendingWrites == true` are filtered out. Posts only appear after the server confirms the full write (text + valid media URLs).
- Posts where any `mediaUrls` entry is empty/blank are filtered out as a defensive guard on the read side.
- Client-side sort by `createdAt` descending replaces the removed `orderBy`.

### Ownership model

- `createdByDisplayId` is stored on every post document.
- At render time, `PostCard` receives the current user's `displayId`.
- `post.createdByDisplayId == currentDisplayId` → owner → show ⋮ menu.
- The ⋮ menu offers **Edit** and **Delete** only to the post owner.

### Controllers

**`PostController`** (`features/home/controller/post_controller.dart`)
- `ChangeNotifier`
- Opens a real-time `collectionGroup('posts')` stream on init (no `orderBy`).
- Exposes: `List<PostModel> posts`, `bool isLoading`, `String? errorMessage`.
- `toggleLike(PostModel, String currentDisplayId)` — `FieldValue.arrayUnion/Remove` on `likedBy` + `FieldValue.increment(±1)` on `likes`.
- `deletePost(PostModel)` — deletes the Firestore document. Caller must verify ownership first.
- Dispose cancels the stream subscription.

**`PostDetailsController`** (`features/home/controller/post_details_controller.dart`)
- `ChangeNotifier`, requires `employeeId` + `postId`.
- Streams a single post document (regular snapshots — immediate updates for likes).
- Streams the `comments` subcollection with `includeMetadataChanges: true`; sorts client-side ascending (oldest first); `null createdAt` (pending write) floats to bottom.
- `toggleLike(String currentDisplayId)` — same array + increment logic as PostController.
- `addComment({text, createdByDisplayId, createdByName})` — `WriteBatch`: sets comment doc + increments `commentsCount`.
- Dispose cancels both subscriptions.

**`CreatePostController`** (`features/home/controller/create_post_controller.dart`)
- `ChangeNotifier`, requires `EmployeeModel`. Accepts optional `PostModel? existingPost`.
- `isEditMode` → true when `existingPost != null`. Pre-fills `textController` and `_keptMediaUrls`.
- Media state:
  - `keptMediaUrls` — existing remote URLs from the post being edited (user can remove).
  - `pickedImages` — newly picked local `XFile`s for this session (user can remove).
  - `totalMediaCount` — `keptMediaUrls.length + pickedImages.length`, max 4.
- `pickImages()` — opens gallery, respects the 4-image cap.
- `removeKeptMedia(index)` — removes a remote URL from the kept list.
- `removeNewImage(index)` — removes a local pick.
- `onTextChanged()` — call from `TextField.onChanged` to refresh `canPost`.
- `submitPost()`:
  - Uploads `pickedImages` with rollback on failure (see Upload contract).
  - **Create mode**: writes a new Firestore doc with `toJson()`.
  - **Edit mode**: updates only `text` and `mediaUrls` on the existing doc.
  - Returns `true` on success.

### Screens

**`HomeScreen`** (`features/home/home_screen.dart`)
- Provides `PostController`.
- Shows shimmer cards while loading, error state, empty state, or feed.
- Passes `employee.displayId` as `currentDisplayId` to every `PostCard`.
- **`NewChatScreen`** (`features/new_chat/new_chat_screen.dart`) employee tiles show only `displayId` (no name). `chatTitle` passed to `EmployeeChatScreen` is also `other.displayId`.
- Handles **delete confirmation dialog** before calling `PostController.deletePost`.
- Fixed **ADD POST** gradient button at bottom (same style as NEW CHAT in chat list).

**`CreatePostScreen`** (`features/home/create_post_screen.dart`)
- Accepts `employee` (required) and `existingPost` (optional, triggers edit mode).
- Provides `CreatePostController`.
- AppBar title: `'New Post'` / `'Edit Post'`. Button label: `'POST'` / `'SAVE'`.
- `_MediaPreviewGrid` shows two groups of 90×90 thumbnails (kept remote + new local),
  each with an ✕ remove button.
- Bottom toolbar **Photo (n/4)** picker, disabled at limit of 4.

### PostCard layout
```
┌─────────────────────────────────────────────┐
│ [Avatar]  EMP-XXXXX              2h ago  ⋮  │  ← ⋮ only for post owner
│                                              │
│  Post text content...                        │
│                                              │
│  [single full-width image  (h=240)]          │
│  or [horizontal scroll of 200×200 tiles]     │
│ ──────────────────────────────────────────── │
│  ♡ 12 Likes     💬 5 Comments               │
└─────────────────────────────────────────────┘
```

Field usage in the card (both `PostCard` in feed and `PostDetailsScreen`):
- `createdByDisplayId` → sole identifier in header (green, bold); compared to `currentDisplayId` for ownership. Employee name is **not shown** anywhere.
- `_PostAvatar` / `_Avatar` shows first character of `createdByDisplayId` as the avatar initial.
- `createdAt` → relative time string top-right (`Just now`, `2m ago`, `3h ago`, `5d ago`, `d/m/y`)
- `text` → body paragraph (omitted if empty)
- `mediaUrls` → single full-width image or horizontal scroll of tiles
- `likes` → `♡ N Likes` chip in footer
- `commentsCount` → `💬 N Comments` chip in footer

**`PostDetailsScreen`** (`features/home/post_details_screen.dart`)
- Post header: only `createdByDisplayId` shown (no name). `_Avatar` takes `displayId`.
- Comment tiles (`_CommentTile`): only `createdByDisplayId` shown as the primary label (no name row). `_Avatar` takes `displayId`.

---

## Admin Role — Screen Map

`AdminMainScreen` is the shell with a 4-tab `BottomNavigationBar`.

| Index | Label | Screen |
|---|---|---|
| 0 | REQUESTS | `RequestsScreen` |
| 1 | EMPLOYEES | `EmployeesScreen` |
| 2 | LOGS | `LogsScreen` |
| 3 | PROFILE | `AdminProfileScreen` |

---

## Primary Admin Role — Screen Map

`MainScreen` — own shell (see `lib/roles/primary Admin/Features/Main/Main_screen.dart`).

---

## Session Management

`SessionManager.instance` (singleton)
- `logout(context, {reason})` — signs out Firebase Auth, clears SharedPreferences, navigates to `LoginScreen`.
- `ensureRole(context, allowedRoles, [expectedOrganizationId])` — verifies current user's Firestore role + status. Calls `logout` and returns `false` on failure.
- All role-specific main screens call `ensureRole` in `initState` via `addPostFrameCallback`.

---

## Design Tokens

| Token | Value |
|---|---|
| Primary / accent | `#4ADE80` |
| Scaffold bg | `#0B1326` |
| Card bg | `#1A2035` |
| Section bg | `#1E2640` |
| Bottom nav bg | `#131929` |
| Input border | `#2A3550` |
| Text title | `#DAE2FD` |
| Text muted | `#94A3B8` |
| Error | `#EF4444` |
| Gradient | `#4BE277` → `#22C55E` |
| Button text | `#0A0F1A` |

Active nav-item indicator: 3 × 36 px green bar above the icon.

---

## Firebase Storage Paths

| Purpose | Path |
|---|---|
| Post media | `employees/{employeeId}/posts/{timestamp}_{index}.jpg` |

---

## Key Dependencies

```yaml
provider: ^6.1.1
firebase_core: ^3.13.0
firebase_auth: ^5.5.2
cloud_firestore: ^5.6.6
firebase_storage: ^12.4.10
image_picker: ^1.2.1
cached_network_image: ^3.4.1
shimmer: ^3.0.0
google_fonts: ^6.1.0
flutter_screenutil: ^5.9.0
```
