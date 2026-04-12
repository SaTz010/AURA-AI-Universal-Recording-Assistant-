# Copilot Instructions for AURA

## Build, test, and lint commands

Use Flutter from repository root:

```bash
flutter pub get
flutter analyze
flutter test
flutter test test/widget_test.dart
flutter test test/widget_test.dart --plain-name "Counter increments smoke test"
flutter run --dart-define-from-file=firebase.env.json
flutter build apk --dart-define-from-file=firebase.env.json
```

Firebase is initialized from `lib/firebase_options.dart` and values are expected from `firebase.env.json` via `--dart-define-from-file`.

## High-level architecture

- App bootstrap is in `lib/main.dart`: it initializes Firebase, then starts `MyApp` with two app-wide `InheritedNotifier` providers:
  - `AuraThemeProvider` (`lib/theme/theme_provider.dart`)
  - `AuraAuthProvider` (`lib/providers/auth_provider.dart`)
- Navigation is primarily named-route based from `MaterialApp.routes` in `main.dart`, with splash as entry (`AuraSplashScreen`) and route constants like `/auth`, `/home`, `/recordings`, `/history`, `/summary`, etc.
- Auth flow:
  - `lib/services/auth_service.dart` wraps Firebase Auth + Google Sign-In and shared-preferences user cache.
  - `lib/providers/auth_provider.dart` exposes auth state/loading/errors to UI and maps Firebase/Google errors into user-facing messages.
  - `lib/screens/initial_animation.dart` decides post-splash destination based on auth session.
- Audio flow:
  - `lib/screens/home_screen.dart` is the primary interaction screen and entry point to recording.
  - `lib/screens/recording_session_screen.dart` records with `audio_waveforms` `RecorderController`, writes `.m4a` files to app documents directory, and renames with the `Aura_<n>` pattern.
  - `lib/screens/recordings_screen.dart` reads those same local `.m4a` files, plays via `just_audio`, and supports deletion.
- User profile header in `home_screen.dart` uses a Firestore stream (`users/<uid>`) to resolve display name/photo with FirebaseAuth fallback values.

## Key conventions in this repository

- Theme/token system is strict and centralized:
  - Colors must come from `AuraThemeColors.of(context)` (`lib/theme/aura_theme.dart`), not raw hex in widgets.
  - Typography/spacing/radius/elevation/motion should come from `AuraTypography`, `AuraSpacing`, `AuraRadius`, `AuraElevation`, `AuraMotion` (`lib/theme/aura_tokens.dart`).
  - See `DESIGN_SYSTEM.md` for authoritative visual rules (dark default, semantic color roles, motion/haptic guidance).
- This codebase uses provider-like state via custom `InheritedNotifier` wrappers (`AuraThemeProvider`, `AuraAuthProvider`) rather than external state frameworks.
- Bottom navigation semantics are shared across screens through `MainBottomNav` (`lib/screens/widgets/main_bottom_nav.dart`) with fixed index mapping:
  - `0=Home`, `1=Recordings`, `2=History`, `3=Summary`.
- Interactive UI patterns commonly include `Material + InkWell` wrappers and explicit `HapticFeedback` calls for taps/selection.
- Current `test/widget_test.dart` is template-era and not aligned with Firebase-initialized app startup; treat it as baseline until replaced with app-aware tests/mocks.
