# AURA — Project Description (AI Code Review Input)

> **Project:** AURA (Audio Understanding & Recording Assistant)
>
> **Document purpose:** Provide a complete technical + contextual overview of the codebase for an AI code reviewer (e.g., Claude) so it can deliver deep architectural and implementation feedback **without needing to read the code first**.
>
> **Last reviewed:** 2026-04-25

---

## 1) Project Overview

### 1.1 Project name and purpose
**AURA (Audio Understanding & Recording Assistant)** is a Flutter application that helps users **record or import audio**, then converts that audio into **structured, readable outputs** using an external AI backend:

- Cleaned / normalized transcript
- Context-aware summary
- Optional translation
- Shareable text + PDF export

### 1.2 Problem it solves
Spoken information (meetings, lectures, interviews, personal voice notes) is difficult to search, skim, and convert into action. AURA bridges the gap between **raw audio** and **actionable information** by:

- Capturing audio reliably on-device
- Offloading transcription/summarization to a backend
- Persisting results locally for offline access and later reuse

### 1.3 Target users
- Students processing lecture recordings
- Professionals processing meetings/interviews
- Individuals capturing and summarizing personal notes
- Users who need rapid recall + export/shareable summaries

---

## 2) Core Features

### 2.1 Authentication (Google + Guest)
- **Google Sign-In** using Firebase Auth + Google Sign-In.
- **Guest mode** using Firebase anonymous authentication.
- App-wide auth state is exposed through an `InheritedNotifier` provider.

**User flow:**
1. App starts → initializes Firebase.
2. If a session exists → navigates to main tabs.
3. If not → shows auth screen.
4. User chooses:
   - Continue with Google, or
   - Continue as Guest.

### 2.2 Home dashboard: record or upload
- Primary action: a large mic button that opens a recording session.
- Secondary action: upload/import an audio file from device storage.
- Optional backend “wake” ping is triggered to reduce cold-start latency (Render).

**User flow (upload):**
1. User taps upload.
2. File picker allows selecting common formats (m4a/mp3/wav/aac/flac/ogg/opus).
3. The selected file enters the same summarization flow as recordings.

### 2.3 Audio recording session
- Audio recording uses `audio_waveforms` `RecorderController`.
- Recorder settings are tuned for broad compatibility and speech capture:
  - AAC in MP4 container (`.m4a`)
  - 44.1 kHz sample rate
  - 128 kbps bitrate
- Recording is saved into per-user storage (guest gets a `_guest` bucket).
- The user is prompted for a friendly name; file is renamed accordingly.

**User flow:**
1. User taps mic → app requests mic permission.
2. Recording starts.
3. User stops → app finalizes file safely.
4. User chooses a name → app renames and saves.

### 2.4 Recordings library (local)
- Lists locally stored recordings (.m4a) for the effective user.
- Inline playback using `just_audio`.
- Supports:
  - Play/pause
  - Seek via slider
  - Skip ±15 seconds
  - Duration caching
  - Delete recording
  - Summarize via backend
  - View stored summary when available
- Includes filter + sort UI (time/name/size; recorded vs uploaded inference).

### 2.5 Context-aware AI processing (FastAPI backend)
AURA integrates with a hosted FastAPI backend:

- **Base URL (default):** `https://backendforaura.onrender.com`
- **Warm-up endpoint:** `GET /wake`
- **Processing endpoint:** `POST /process-audio` (multipart/form-data)

**Processing inputs:**
- `audio`: file (required)
- `category`: string (required; must match one of 7 categories exactly)
- `detail`: string (optional)

**Supported categories (UI-controlled):**
- Medical consultation
- Business meeting
- Interview
- Lecture / class
- Personal note
- Legal / official
- Other

**Processing outputs (conceptual):**
- `transcript`: string
- `summary`: string
- `translation`: optional string
- `cost`: numeric

**Reliability behavior:**
- Long-running request support: ~120s timeouts.
- Retry with exponential backoff (up to 2 retries).
- User-friendly errors surfaced via snackbars.

### 2.6 Summaries library (local, offline)
Summarization results are persisted locally so users can:
- reopen a summary later even without connectivity,
- export PDF again,
- share/copy text,
- delete saved summary entries.

The summary screen maintains an index of summaries and also filters out entries whose audio no longer exists.

### 2.7 Result viewing + export/sharing
- Summary detail shows:
  - Summary
  - Transcript
  - Translation (if available)
- Actions:
  - Copy text to clipboard
  - Share text (Share sheet)
  - PDF export

**PDF export:**
- Generates a structured report using the `pdf` package.
- Preview uses the `printing` package.
- Android “download” uses Storage Access Framework (SAF) via a method channel that:
  - opens a “create document” picker,
  - writes bytes to the returned URI,
  - stores a persistent URI to re-open later.

### 2.8 Theme system (design tokens)
- Strict semantic color roles via `AuraThemeColors.of(context)`.
- Design tokens (typography, spacing, radius, motion, elevation) are centralized.
- Theme mode is controlled by an `InheritedNotifier` provider.

### 2.9 Profile + settings
- Profile shows basic identity info for signed-in users and local stats (recordings and summaries totals).
- Guest users see a gate prompting them to log in.
- Settings includes theme selection and basic placeholders.

### 2.10 Placeholders / “coming soon”
- History screen: present but currently “Coming soon”.
- Several settings items are placeholders.

---

## 3) Tech Stack

### 3.1 Frontend
- **Framework:** Flutter (Material 3)
- **Language:** Dart
- **Key packages:**
  - `firebase_core`, `firebase_auth`, `google_sign_in`
  - `cloud_firestore`
  - `audio_waveforms` (recording)
  - `just_audio` (playback)
  - `dio` (multipart uploads, retries, timeouts)
  - `http` (wake ping)
  - `file_picker`
  - `path_provider`, `shared_preferences`, `permission_handler`
  - `pdf`, `printing`, `share_plus`

### 3.2 Backend
- **External service:** FastAPI (hosted on Render)
- Responsibilities assumed on backend side:
  - file ingestion
  - transcription
  - summarization
  - optional translation
  - returning a JSON response

### 3.3 Database / persistence
- **Firebase Auth:** identity + sessions.
- **Cloud Firestore:** currently used for light profile enrichment.
- **Local storage:**
  - recordings as `.m4a` files in app documents directory
  - summaries index as JSON file per user
  - shared-preferences cache of basic user profile fields

### 3.4 Why these choices (brief)
- Flutter: single codebase, fast iteration for mobile UI.
- Firebase Auth: robust, production-grade auth quickly.
- Local-first storage: offline access and reduced infrastructure cost.
- Dio: mature multipart handling and detailed networking error control.

---

## 4) System Architecture

### 4.1 High-level architecture
**Client-heavy Flutter app** + **external FastAPI AI backend** + **Firebase identity**.

- The Flutter app controls the UX flow and local persistence.
- The backend remains largely stateless (process file → return result).
- Firestore is used minimally (profile stream).

### 4.2 Data flow (input → output)
1. **Input acquisition**
   - Record audio (mic) OR pick audio file (upload).
2. **Local persistence**
   - Save audio file to per-user directory.
3. **Context selection**
   - User selects category + optional detail.
4. **Backend processing**
   - App uploads audio via multipart form-data.
   - Backend transcribes/summarizes.
5. **Result handling**
   - App parses response into a stable model.
6. **Cache & access**
   - Persist summary entry to local summaries JSON index.
7. **Export**
   - Share/copy text; export PDF; on Android store SAF URI for future open.

### 4.3 Integration points
- Firebase initialization & auth session detection.
- Firestore stream: `users/<uid>` for name/photo.
- FastAPI API: `/process-audio` and `/wake`.
- Android platform channel for PDF SAF operations.

---

## 5) Key Modules & Components

### 5.1 Bootstrap, routing, and providers
- App initializes Firebase and creates two app-wide providers:
  - Auth provider (session state)
  - Theme provider (theme mode)

Navigation is primarily named routes; main UI uses a tab scaffold with a bottom nav.

### 5.2 Auth module
- `AuthService`: wraps Firebase Auth + Google Sign-In, caches basic profile info in shared preferences.
- `AuthProvider`: exposes auth state + errors and listens to `FirebaseAuth.authStateChanges()`.

### 5.3 Recording module
- Recording session screen uses `RecorderController`.
- Storage is handled by a `RecordingsStorage` helper that:
  - creates per-user directories,
  - migrates legacy recordings from a flat root folder.

### 5.4 Playback module
- `RecordingsScreen` uses `just_audio` to play local files.
- Maintains duration cache and handles inline player UI.

### 5.5 Summarization flow module
- `SummarizationFlow` orchestrates:
  - reuse of cached summary if it exists,
  - category selection,
  - extra details input,
  - loading screen,
  - API call,
  - local persistence,
  - navigation to summary detail.

### 5.6 Backend API module
- `ApiService`:
  - validates categories,
  - uploads multipart requests with Dio,
  - supports long timeouts and retry,
  - maps errors into `ApiException` with user-friendly messages.

### 5.7 Summary persistence module
- `SummariesStorage` stores a JSON index per user.
- Summary model includes transcript/summary/translation/cost/category and optional `pdfUri`.

### 5.8 PDF export module
- `PdfGenerator` generates PDF bytes and/or writes files.
- `PdfPreviewScreen` shows a preview and enables Android-only SAF download.
- `PdfSafService` method channel talks to Android code in `MainActivity`.

### 5.9 Theme / design tokens
- `AuraThemeColors` resolves semantic colors.
- `AuraTokens` defines spacing, radii, elevation, motion, typography.
- Theme is controlled by `ThemeNotifier` via `InheritedNotifier`.

---

## 6) Database Design

### 6.1 Firebase Auth
- Identity source: Firebase Auth.
- Two modes:
  - Signed-in (Google): stable `uid`.
  - Guest: anonymous auth; treated as “guest bucket” in local storage helpers.

### 6.2 Firestore
- Current usage is minimal:
  - Collection: `users`
  - Document: `<uid>`
  - Fields used in UI: `name`, `photoUrl`

No recordings or summaries are persisted to Firestore in the current architecture.

### 6.3 Local persistence (primary data store)
**Recordings**
- Stored as `.m4a` files under app documents directory:
  - `recordings/<uid or _guest>/...`

**Summaries**
- Stored as a JSON index file:
  - `summaries/<uid or _guest>/summaries.json`
- Each entry contains:
  - `filePath`, `fileName`, `createdAtMs`, `description`
  - `summary`, `transcript`, `translation?`, `cost`, `category`
  - `pdfUri?` (Android SAF URI)

**Shared preferences**
- Caches `name/email/photoUrl` for faster UI hydration.

---

## 7) Current Implementation Status

### 7.1 Completed
- Firebase initialization + auth-aware app entry
- Google sign-in + guest sign-in
- Local audio recording + naming + persistence
- Recordings list + playback + deletion + filter/sort
- FastAPI integration:
  - multipart upload
  - category validation
  - timeout + retries
  - robust response parsing
- Summaries persistence + list + detail view
- Share/copy + PDF export (including Android SAF download)
- Token-based theming and light/dark mode

### 7.2 Partially implemented
- Firestore is used to **read** `users/<uid>` for profile display, but the app does not guarantee writing/updating those fields.
- History screen exists but is currently placeholder.
- Some Settings sections are placeholders (e.g., notifications/storage).

### 7.3 Known issues / limitations
- **No cloud sync**: summaries and recordings are device-local.
- **Backend availability**: summarization requires network and backend uptime; timeouts are set to 120 seconds.
- **Android-only “download” UX**: SAF-based PDF download is limited to Android; other platforms rely on sharing/preview patterns.
- **Strict categories**: category values must match exactly; UI enforces fixed options.
- Tests exist but may not reflect Firebase-initialized startup patterns (template-era baseline).

---

## 8) Design Decisions & Tradeoffs

### 8.1 Local-first strategy
- Chosen for offline access and reduced backend complexity.
- Tradeoff: no multi-device continuity; manual sharing/export needed.

### 8.2 Stateless-ish backend contract
- Backend processes uploaded audio and returns result.
- Tradeoff: the client must handle compatibility across response schema variations (mitigated by flexible parsing logic).

### 8.3 Strict design token system
- Enforces UI consistency and prevents ad-hoc styling.
- Tradeoff: faster UI prototyping requires working through tokens/semantic roles.

### 8.4 Wake endpoint
- Improves perceived responsiveness for cold-start hosting.
- Tradeoff: additional network call and reliance on backend support.

---

## 9) Scalability & Future Improvements

### 9.1 Data sync & multi-device
- Persist summary metadata in Firestore and audio in cloud storage.
- Add per-user indexes, pagination, and retention policies.

### 9.2 Search and organization
- Full-text search over transcripts/summaries.
- Tagging, topic segmentation UI, and filters.

### 9.3 Reliability & UX
- Upload progress UI, cancellation support, background queue.
- Chunked/resumable uploads for large files.

### 9.4 Security & privacy
- Encryption at rest for local transcripts/summaries.
- Clearer consent and jurisdictional compliance prompts.
- Configurable retention and deletion guarantees.

### 9.5 Backend contract hardening
- Versioned API responses.
- Explicit schema and more stable keys.

---

## 10) Usage Flow (Step-by-step)

1. **Launch app** → Firebase initializes.
2. **Entry decision**:
   - Session exists → main tabs.
   - No session → auth screen.
3. **Sign in** with Google or continue as Guest.
4. **Home**:
   - Tap mic to record OR upload audio from device.
5. **Recording session**:
   - record → stop → name → saved locally.
6. **Recordings**:
   - play audio → optionally summarize.
7. **Summarize**:
   - pick category → optional detail → processing → view results.
8. **Save + revisit**:
   - results are cached locally; available offline.
9. **Export**:
   - copy/share → generate PDF → preview → Android download via SAF.

---

## 11) Deployment & Environment

### 11.1 Running locally
From repo root:

- `flutter pub get`
- `flutter analyze`
- `flutter run --dart-define-from-file=firebase.env.json`

### 11.2 Firebase configuration
- Firebase options are loaded via Dart defines (not committed secrets).
- Real config values are expected in `firebase.env.json` passed with `--dart-define-from-file`.

### 11.3 Backend configuration
- Backend base URL can be overridden at runtime:
  - `--dart-define=AURA_API_BASE_URL=http://...`
- Defaults to the hosted Render backend.

---

## 12) Additional Context (Assumptions, constraints, considerations)

- **Consent / legality:** Audio recording laws vary by jurisdiction. The app includes baseline Terms/Privacy copy reminding responsible usage, but production compliance likely requires stronger UX + documentation.
- **Sensitive data:** Recordings and transcripts can be sensitive (medical/legal). Current architecture sends audio to a third-party backend for processing.
- **Offline behavior:** summaries remain accessible offline once saved, but new summarization requires connectivity.
- **User scoping convention:** storage uses an “effective UID” convention: signed-in `uid` or guest `_guest` folder.

---

### Appendix A — Suggested Reviewer Focus Areas
If you are reviewing this codebase, high-value feedback areas include:

1. API contract stability, versioning, and response validation
2. Privacy and consent UX, plus data retention guarantees
3. Background processing and cancellation for long-running tasks
4. Error handling consistency and user messaging
5. Local storage structure, migration strategy, and test coverage
6. Separation of concerns between UI orchestration, persistence, and networking
