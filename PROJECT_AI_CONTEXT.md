# Project AI Context

Use this file as a handoff document when sharing the project with an AI assistant. It summarizes the app purpose, structure, dependencies, data model, main flows, and important implementation conventions.

## Project Summary

This is a Flutter application named `project_1`. The visible app title in `lib/main.dart` is `Marvel`, and the role selection screen brands the product as `The Mini Marvels`.

The app is a parent-child task and learning platform. Parents can register/login, manage children, assign tasks with optional photo/video examples, review submitted task proof, and award XP. Children can log in with a parent email plus PIN, see their hero profile, complete assigned tasks, submit photo/video proof, watch story videos, play games, and record feelings.

The backend is Supabase. Supabase Auth is used for parent accounts. Custom Supabase tables are used for parent profiles, child profiles, assigned tasks, child submissions, and story videos. Supabase Storage is used for task media.

## Tech Stack

- Flutter SDK with Dart `^3.9.2`
- Material UI
- Supabase via `supabase_flutter`
- Media picking via `image_picker` and `image_picker_for_web`
- Local/web video playback via `video_player`
- YouTube playback via `youtube_player_iframe`
- External links/web content via `url_launcher` and `webview_flutter`
- Linting via `flutter_lints`

Primary dependency file: `pubspec.yaml`.

## App Startup

Entry point: `lib/main.dart`

Startup behavior:

1. Calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Initializes Supabase:
   - URL: `https://ptrhkseofzxeilzlmjmq.supabase.co`
   - Anon key is currently hardcoded in `main.dart`.
3. Runs a `MaterialApp`:
   - `title: "Marvel"`
   - `debugShowCheckedModeBanner: false`
   - `home: RoleScreen()`
4. Exposes `final supabase = Supabase.instance.client;`.

Important security note: the Supabase anon key is public by design, but future production work should still rely on strict Row Level Security policies and should avoid committing service-role keys or private secrets.

## Repository Structure

Important root files:

- `pubspec.yaml`: Flutter dependencies and project metadata.
- `pubspec.lock`: Locked dependency versions.
- `analysis_options.yaml`: Flutter lint configuration.
- `README.md`: Default Flutter starter README.
- `PROJECT_AI_CONTEXT.md`: This AI handoff document.

Important app folders:

- `lib/main.dart`: App bootstrap and Supabase initialization.
- `lib/user_authentication/`: Role selection, parent auth, child auth.
- `lib/parent/`: Parent dashboard, child management, task assignment, verification.
- `lib/child/`: Child dashboard, task list/details, games, feelings.
- `lib/child/All Video Feature/`: Story video list/player, video data models, quiz pages.
- `test/`: Default Flutter test scaffold.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Flutter platform folders.

Generated/build folders such as `.dart_tool/` and `build/` should not be used for app logic.

## User Roles and Navigation

### Role Selection

File: `lib/user_authentication/role_screen.dart`

`RoleScreen` lets the user choose:

- Child: navigates to `ChildLogin`.
- Parent: checks `Supabase.instance.client.auth.currentUser`.
  - If a parent auth session exists, navigates to `ParentAuthentication` for PIN verification.
  - If no session exists, navigates to `ParentRegister`.

### Parent Flow

Main parent files:

- `lib/user_authentication/parent_register.dart`
- `lib/user_authentication/parent_login.dart`
- `lib/user_authentication/parent_authentication.dart`
- `lib/parent/parent_dashboard.dart`
- `lib/parent/parenthub.dart`
- `lib/parent/managepage.dart`
- `lib/parent/addmemberpage.dart`
- `lib/parent/addnewtaskpage.dart`
- `lib/parent/provided_tasks.dart`
- `lib/parent/allassignedtaskpage.dart`
- `lib/parent/taskverificationpage.dart`
- `lib/parent/editprofilepage.dart`
- `lib/parent/gamelimitspage.dart`

Parent behavior:

- Parent registration uses Supabase Auth sign-up, then inserts a parent profile into the `parent` table.
- Parent login uses Supabase Auth email/password.
- Parent PIN authentication reads `parent.parent_pin` for the current Supabase Auth user.
- Parent dashboard lists children owned by the current parent and counts submitted tasks needing review.
- Parents can assign new tasks to a selected child.
- Parents can review child submissions and approve or reject them.
- On approval, the child's `total_xp` is increased by the task's `reward_xp`.

### Child Flow

Main child files:

- `lib/user_authentication/child_login.dart`
- `lib/user_authentication/child_register.dart`
- `lib/child/child_homepage.dart`
- `lib/child/all_tasks_page.dart`
- `lib/child/task_details_page.dart`
- `lib/child/games_page.dart`
- `lib/child/game_player_page.dart`
- `lib/child/my_feelings_page.dart`

Child behavior:

- Child login checks the `child` table using parent information and the child PIN.
- Child homepage loads the child profile from `child` by `child_id`.
- Child homepage shows name, avatar, XP, level, and quick actions:
  - All Tasks
  - Story Videos
  - Games
  - My Feelings
- Child task list fetches assigned tasks where `status = 'assigned'`.
- Child task details fetches one assigned task, displays parent instructions/media, lets the child upload image/video proof, and updates the task to `submitted`.
- The child task page includes a helper AI button using `https://chatai.google.com`.

## Main Feature Areas

### Task Assignment

File: `lib/parent/addnewtaskpage.dart`

Parents create tasks with:

- `task_name`
- optional `task_details`
- `reward_xp`
- optional example image/video media

The page verifies the selected child belongs to the current parent before inserting into `assigned_tasks`.

Inserted fields include:

- `parent_id`
- `child_id`
- `task_name`
- `task_details`
- `reward_xp`
- `example_media_url`
- `status: 'assigned'`
- `assigned_date`
- `due_date: null`

Task example media is uploaded to Supabase Storage bucket `task-media`, and only the storage path is saved in `assigned_tasks.example_media_url`.

### Child Task Completion

File: `lib/child/task_details_page.dart`

The child task page:

- Fetches a single task from `assigned_tasks`.
- Requires `assigned_task_id`, `child_id`, `status = 'assigned'`, and `expires_at` greater than current UTC time.
- Creates signed URLs for task media stored in `task-media`.
- Allows image/video proof upload.
- Uploads child proof to `task-media`.
- Inserts a child submission.
- Updates `assigned_tasks.status` to `submitted`.

Important note: this file inserts into `child_task_submission` singular, while other files read/update `child_task_submissions` plural. This may be a bug or table naming mismatch. Verify the actual Supabase table name before modifying this flow.

### Parent Task Verification

File: `lib/parent/taskverificationpage.dart`

The verification page:

- Reads a child submission from `child_task_submissions`.
- Joins the related `assigned_tasks` row.
- Converts child proof media paths into signed Supabase Storage URLs.
- Allows parent to approve or reject.

Approve behavior:

- Prevents double review by checking `reviewed_at` and `review_feedback`.
- Reads `assigned_tasks.reward_xp`.
- Reads `child.total_xp`.
- Updates `child.total_xp = currentXp + rewardXp`.
- Updates submission with:
  - `reviewed_by_parent_id`
  - `reviewed_at`
  - `review_feedback: 'approved'`

Reject behavior:

- Updates submission with:
  - `reviewed_by_parent_id`
  - `reviewed_at`
  - `review_feedback: 'not-approved'`

### Story Videos

Files:

- `lib/child/All Video Feature/all_videos_page.dart`
- `lib/child/All Video Feature/video_player_page.dart`
- `lib/child/All Video Feature/video_model.dart`
- `lib/child/All Video Feature/quiz_page.dart`
- `lib/child/All Video Feature/task_master_page.dart`

Story videos are fetched from the `story_videos` table where `is_active = true`, ordered by newest first.

Expected story video fields:

- `story_id`
- `title`
- `description`
- `youtube_url`
- `youtube_video_id`
- `is_active`
- `created_at`

Thumbnails are derived from YouTube video IDs:

```text
https://img.youtube.com/vi/<youtube_video_id>/hqdefault.jpg
```

`VideoPlayerPage` accepts either a clean 11-character YouTube video ID or common YouTube URL formats and extracts the ID. It uses `youtube_player_iframe`.

`video_model.dart` contains older/general models:

- `QuizQuestion`
- `VideoStoryData`

Those models expect keys such as `questionText`, `options`, `correctAnswer`, `title`, `videoPath`, `thumbnailPath`, `xpReward`, and `quizQuestions`.

### Games

Files:

- `lib/child/games_page.dart`
- `lib/child/game_player_page.dart`

The child dashboard links to games. `GamePlayerPage` uses WebView behavior through the app's webview dependency.

### Feelings

File: `lib/child/my_feelings_page.dart`

The child can select/save a feeling locally in the page UI. Review the file before assuming persistence exists in Supabase.

## Supabase Tables Used By Code

The app references these tables:

- `parent`
- `child`
- `assigned_tasks`
- `child_task_submission`
- `child_task_submissions`
- `story_videos`

### parent

Observed fields:

- `user_id`
- `parent_pin`
- likely profile fields from registration such as parent name/email, depending on `parent_register.dart`

Usage:

- Parent registration inserts into `parent`.
- Parent PIN authentication selects `parent_pin` by `user_id`.

### child

Observed fields:

- `child_id`
- `parent_id`
- `child_name`
- `pin`
- `avatar_url`
- `total_xp`
- `current_level`
- `created_at`

Usage:

- Child registration inserts into `child`.
- Child login selects `child_id, child_name` by parent and PIN.
- Parent dashboard lists children by `parent_id`.
- Child homepage reads profile, XP, and level.
- Verification approval updates `total_xp`.

### assigned_tasks

Observed fields:

- `assigned_task_id`
- `parent_id`
- `child_id`
- `task_name`
- `task_details`
- `reward_xp`
- `example_media_url`
- `status`
- `assigned_date`
- `due_date`
- `expires_at`
- `created_at`

Status values used by code:

- `assigned`
- `submitted`

Usage:

- Parent creates tasks.
- Child fetches tasks with `status = 'assigned'`.
- Child submission updates status to `submitted`.
- Parent dashboard counts submitted tasks.
- Parent task history lists assigned tasks.

### child_task_submissions / child_task_submission

Observed fields:

- `submission_id`
- `assigned_task_id`
- `child_id`
- `child_note`
- `child_media_url`
- `submitted_at`
- `reviewed_by_parent_id`
- `reviewed_at`
- `review_feedback`

Review feedback values used:

- `pending`
- `approved`
- `not-approved`

Important caveat:

- `task_details_page.dart` inserts into `child_task_submission` singular.
- `provided_tasks.dart` and `taskverificationpage.dart` use `child_task_submissions` plural.
- Confirm and normalize the table name to avoid broken submissions or review screens.

### story_videos

Observed fields:

- `story_id`
- `title`
- `description`
- `youtube_url`
- `youtube_video_id`
- `is_active`
- `created_at`

Usage:

- Child story video page fetches active records.
- Video thumbnails are generated from `youtube_video_id`.
- Playback uses either `youtube_video_id` or extracted ID from `youtube_url`.

## Supabase Storage

Bucket used:

- `task-media`

Storage path conventions:

- Parent example media:

```text
<parentId>/children/<childId>/assigned_tasks/<timestamp>.<extension>
```

- Child submission media:

```text
<parentId>/children/<childId>/assigned_tasks/<assignedTaskId>/submissions/<timestamp>.<extension>
```

Important convention:

- Store only the storage path in database fields.
- Do not store short-lived signed URLs as permanent database values.
- When displaying media, create signed URLs with `createSignedUrl(path, 60 * 60 * 24 * 7)`.

Media support:

- Images: jpg/jpeg, png, webp, gif.
- Videos: mp4 and webm are preferred.
- UI warns that browser playback works best with MP4 H.264/AAC or WebM.

## UI and Design Conventions

The app is designed mostly as a mobile-width experience centered in a wider viewport:

- Many screens wrap content in a centered `Container(width: 430)`.
- Background outside the mobile canvas often uses `Colors.black12`.
- Parent screens use white cards, light blue backgrounds, and purple accent colors.
- Child screens use playful purple gradients, clouds/stars, hero language, XP, levels, and large friendly cards.
- Navigation mostly uses `Navigator.push`, `Navigator.pushReplacement`, and `MaterialPageRoute`.

Common colors:

- Primary purple: `Color(0xFF6200EE)`
- Deep child purple: `Color.fromARGB(255, 124, 58, 237)`
- Light app background: `Color(0xFFF7F8FC)`
- XP/yellow accent: `Color(0xFFFBBF24)` or `Color(0xFFFFC914)`

When editing UI, preserve the mobile-first 430px centered layout unless intentionally redesigning the whole app.

## Known Caveats and Issues To Check

- `README.md` is still the default Flutter README and does not describe the real app.
- `pubspec.yaml` does not declare image assets, but `RoleScreen` references:
  - `assets/child_avatar.png`
  - `assets/parent_avatar.png`
  These images may not exist or may not be registered.
- There is a likely table name mismatch:
  - insert: `child_task_submission`
  - reads/updates: `child_task_submissions`
- `assigned_tasks.expires_at` is required by `TaskDetailsPage`; if rows are created without `expires_at`, child task loading may fail or mark tasks unavailable.
- `AddNewTaskPage` currently inserts `due_date: null` and does not set `expires_at`.
- `QuizPage.uploadScoreToDatabase` should be reviewed before assuming quiz XP is persisted.
- Some files contain comments from previous generated edits. Keep future edits focused and avoid broad rewrites.
- Git status currently shows many modified/untracked files. Do not reset or revert user work unless explicitly asked.

## How To Run

Typical local commands:

```powershell
flutter pub get
flutter run
```

For web:

```powershell
flutter run -d chrome
```

For checks:

```powershell
flutter analyze
flutter test
```

Network access and valid Supabase policies are required for real app flows.

## Suggested AI Instructions For Future Work

When asking another AI to work on this project, include this file and say:

```text
Read PROJECT_AI_CONTEXT.md first. Then inspect the exact files related to my request before editing. Preserve the current Flutter/Supabase patterns, the 430px centered mobile layout, and the storage-path-to-signed-URL convention. Do not reset unrelated git changes.
```

For backend-related work, also provide the real Supabase schema or SQL migrations if available, because this repo does not include database migrations.

## High-Value Next Improvements

- Replace the default `README.md` with a project-specific README.
- Move Supabase URL/key setup to environment or generated config conventions where appropriate.
- Add/verify Supabase RLS policies for all parent/child/task/submission tables.
- Normalize `child_task_submission` versus `child_task_submissions`.
- Ensure assigned tasks get an `expires_at` value if expiration is required.
- Add assets to `pubspec.yaml` or remove missing asset references.
- Add tests for YouTube ID extraction, storage path extraction, task status transitions, and XP approval logic.
