# AURA Design System Documentation

> Single source of truth for all visual decisions.  
> Last updated: February 2026 — v1.0

---

## 1. Color Palette

### 1.1 Brand Colors (Immutable)

| Token           | Hex         | Usage                                        |
|-----------------|-------------|----------------------------------------------|
| `spaceDark`     | `#0B0D10`   | Primary background (dark mode)               |
| `charcoal`      | `#1C1F26`   | Surface — cards, drawers, app bars (dark)     |
| `charcoalLift`  | `#252830`   | Elevated surface — layered elements (dark)    |
| `coolGrey`      | `#6B7280`   | Secondary icons, borders, tertiary text       |
| `mutedGrey`     | `#9CA3AF`   | Body text, secondary labels                   |
| `iceBlue`       | `#D9DFF0`   | Primary accent, headings, CTA (dark mode)     |
| `frost`         | `#E6EAF5`   | High-emphasis text (dark mode)                |

### 1.2 Light Mode Palette (Derived)

| Token            | Hex         | Usage                                       |
|------------------|-------------|---------------------------------------------|
| `lightBg`        | `#F5F6FA`   | Primary background (light mode)             |
| `lightSurface`   | `#FFFFFF`   | Surface — cards, drawers, app bars           |
| `lightElevated`  | `#F0F1F5`   | Elevated surface                             |
| `darkText`       | `#1A1C22`   | Primary text                                 |
| `mediumText`     | `#4B5563`   | Secondary text                               |
| `lightMuted`     | `#6B7280`   | Tertiary text, icons                         |
| `lightAccent`    | `#3B4A6B`   | Accent soft                                  |
| `lightAccentAlt` | `#2C3751`   | Primary accent, buttons (light mode)         |

### 1.3 Semantic Color Roles

Colors are resolved dynamically via `AuraThemeColors.of(context)`:

| Role             | Dark Mode       | Light Mode        |
|------------------|-----------------|-------------------|
| `background`     | spaceDark       | lightBg           |
| `surface`        | charcoal        | lightSurface      |
| `surfaceElevated`| charcoalLift    | lightElevated     |
| `textPrimary`    | frost           | darkText          |
| `textSecondary`  | mutedGrey       | mediumText        |
| `textTertiary`   | coolGrey        | lightMuted        |
| `accent`         | iceBlue         | lightAccentAlt    |
| `micButton`      | iceBlue         | lightAccentAlt    |
| `micIcon`        | spaceDark       | lightBg           |
| `border`         | coolGrey @ 15%  | coolGrey @ 12%    |
| `divider`        | coolGrey @ 40%  | coolGrey @ 20%    |
| `iconDefault`    | coolGrey        | mediumText        |

### 1.4 Rules
- **Never** hard-code hex values in widgets — always use `AuraThemeColors.of(context)`.
- Brand colors in `AuraColors` are `static const` and must not be modified.
- When adding a new semantic role, add it to both dark and light resolvers in `AuraThemeColors`.

---

## 2. Typography System

**Font family:** Poppins (SemiBold 600, Regular 400)

All typography is accessed via `AuraTypography.<style>(color)`.

| Style            | Size | Weight | Letter Spacing | Line Height | Usage                       |
|------------------|------|--------|----------------|-------------|-----------------------------|
| `displayLarge`   | 28   | 600    | 4.0            | 1.3         | Splash brand text           |
| `headlineLarge`  | 24   | 600    | 6.0            | 1.3         | Brand headings (AURA)       |
| `headlineMedium` | 20   | 600    | 0.5            | 1.4         | Section titles              |
| `titleLarge`     | 18   | 600    | 2.0            | 1.4         | AppBar titles               |
| `titleMedium`    | 16   | 600    | 0.3            | 1.4         | Card headers, dialogs       |
| `bodyLarge`      | 14   | 500    | 0.3            | 1.5         | Menu items, primary body    |
| `bodyMedium`     | 14   | 400    | 0.5            | 1.5         | Body text, descriptions     |
| `bodySmall`      | 13   | 400    | 0.3            | 1.5         | Sheet content, hints        |
| `caption`        | 12   | 400    | 0.2            | 1.5         | Metadata, timestamps        |
| `overline`       | 11   | 400    | 1.2            | 1.5         | Subtitles, section headers  |
| `labelSmall`     | 11   | 600    | 0.2            | 1.5         | Small CTAs, import button   |
| `button`         | 14   | 600    | 0.3            | 1.0         | Button labels               |

### Rules
- All text uses Poppins — no exceptions.
- Color is always passed as a parameter to the typography factory, never embedded.
- Tabular figures (`FontFeature.tabularFigures()`) must be used for timers and numeric displays.

---

## 3. Spacing System

Based on a **4-point grid**. All values are in `AuraSpacing`.

| Token    | Value (dp) | Usage                              |
|----------|------------|------------------------------------|
| `xxs`    | 2          | Inline micro-gaps                  |
| `xs`     | 4          | Icon padding, tight gaps           |
| `sm`     | 8          | Between related items              |
| `md`     | 12         | Card internal, list tile vertical  |
| `base`   | 16         | Standard padding, list horizontal  |
| `lg`     | 20         | Section gaps                       |
| `xl`     | 24         | Major section spacing              |
| `xxl`    | 32         | Top/bottom page padding            |
| `xxxl`   | 40         | Hero spacing                       |
| `huge`   | 48         | Large gaps                         |
| `massive`| 64         | Reserved for modal/dialog spacing  |

### Rules
- Never use magic numbers for spacing. Always reference `AuraSpacing`.
- Horizontal page padding: `AuraSpacing.xl` (24) for full-width screens.
- Vertical list padding: `AuraSpacing.lg` (20) top and bottom.

---

## 4. Corner Radii

All via `AuraRadius`:

| Token  | Value (dp) | Usage                              |
|--------|------------|------------------------------------|
| `xs`   | 4          | Small chips, badges                |
| `sm`   | 8          | Buttons, drawer menu items         |
| `md`   | 12         | Cards, recording tiles, inputs     |
| `lg`   | 16         | Bottom sheets, dialogs             |
| `xl`   | 20         | Large modals                       |
| `full` | 999        | Pills, wave bars, circular buttons |

### Rules
- Cards and tiles: `md` (12).
- Buttons and interactive surfaces: `sm` (8).
- Bottom sheets / dialogs: `lg` (16).
- Never mix radii within the same component.

---

## 5. Elevation & Shadows

All via `AuraElevation`:

| Level    | Blur | Spread | Offset       | Usage                          |
|----------|------|--------|--------------|--------------------------------|
| `none`   | 0    | 0      | (0, 0)       | Flat elements                  |
| `low`    | 8    | 0      | (0, 2)       | Cards, recording tiles         |
| `medium` | 16   | 0      | (0, 4)       | Floating cards, bottom bar     |
| `high`   | 24   | 4      | (0, 8)       | Dialogs, elevated overlays     |
| `glow`   | 40   | 10     | (0, 10)      | Mic button halo                |

### Rules
- Shadow color is always derived from a base color with opacity — never pure black.
- `glow` uses dual shadows: accent halo + ground shadow.
- Light mode shadows use the same structure but base color naturally produces softer results.
- Avoid `elevation` in Material widgets — prefer `boxShadow` via `AuraElevation` for consistency.

---

## 6. Component Styles

### 6.1 Buttons

**Primary (ElevatedButton):**
- Background: `accent`
- Text: `micIcon` (contrasting)
- Padding: `xl` horizontal × `md` vertical
- Radius: `sm` (8)
- Elevation: 0 (flat, relies on color contrast)

**Text (TextButton):**
- Color: `textSecondary`
- No background
- Radius: `sm` (8)

**Mic Button (bespoke):**
- 140×140 circle
- Color: `micButton`
- Icon: `micIcon`, 56dp
- Shadow: `AuraElevation.glow(micButton)`
- Scale feedback: 1.0 → 0.92 on press (300ms, `easeInOut`)
- Icon switch: `AnimatedSwitcher` with scale transition (200ms)

### 6.2 Cards / Tiles

- Background: `surface`
- Border: 1px `border`
- Radius: `md` (12)
- Padding: `md` (12) all sides
- Shadow: `AuraElevation.low`

### 6.3 AppBar

- Background: `surface`
- Elevation: 0
- Title: `AuraTypography.titleLarge(textPrimary)`
- Back button: `arrow_back_rounded`, InkWell with `sm` radius

### 6.4 Drawer

- Background: `surface`
- Header: Brand text (`headlineLarge` + `overline`)
- Menu items: InkWell with `sm` radius, `bodyLarge` text
- Highlighted items: 12% `textTertiary` background
- Dividers: `divider` color

### 6.5 Bottom Sheet

- Radius: `lg` top only
- Background: `surface`
- Handle: 36×4 pill, `textTertiary` @ 30%, centered
- Padding: `xl` sides, `xl` top, `xxl` bottom

### 6.6 Dialogs

- Background: `surface`
- Radius: `lg` (16)
- Title: `titleMedium(textPrimary)`
- Content: `bodyMedium(textSecondary)`

### 6.7 Lists

- `ListView.separated` with `SizedBox(height: sm)` separator
- Horizontal padding: `base` (16)
- Vertical padding: `lg` (20)

### 6.8 SnackBar

- Background: `charcoalLift` (dark) / `darkText` (light)
- Text: `bodySmall`
- Behavior: floating
- Radius: `md` (12)

---

## 7. Animation & Motion

All via `AuraMotion`:

| Token            | Duration | Curve        | Usage                          |
|------------------|----------|--------------|--------------------------------|
| `instant`        | 100ms    | —            | Wave bar height transitions    |
| `fast`           | 200ms    | easeInOut    | Icon switches, fade toggles    |
| `normal`         | 300ms    | easeInOut    | Button press, micro-feedback   |
| `slow`           | 500ms    | easeOut      | Page transitions, splash nav   |
| `pageTransition` | 350ms    | easeInOut    | Route transitions              |

| Named Curve   | Curve          | Usage                          |
|---------------|----------------|--------------------------------|
| `standard`    | easeInOut      | General purpose                |
| `decelerate`  | easeOut        | Entering elements              |
| `accelerate`  | easeIn         | Exiting elements               |
| `spring`      | elasticOut     | Playful feedback (reserved)    |

### Rules
- Page transitions: `PageRouteBuilder` with `FadeTransition`, `slow` duration, `decelerate` curve.
- Icon swaps: `AnimatedSwitcher` with `ScaleTransition`, `fast` duration.
- State changes (recording toggle): `AnimatedContainer` / `AnimatedSwitcher`, `fast`.
- Sonar pulse: 1500ms repeating, `easeOut`. Do not change.
- Wave bars: 600ms repeating, staggered sine. Do not change.

---

## 8. Theme Switching

### Architecture

```
MyApp (StatefulWidget)
  └─ AuraThemeProvider (InheritedNotifier<ThemeNotifier>)
       └─ AnimatedBuilder(animation: themeNotifier)
            └─ MaterialApp(
                 theme: buildAuraLightTheme(),
                 darkTheme: buildAuraDarkTheme(),
                 themeMode: themeNotifier.themeMode,
               )
```

### How to read current theme in any widget
```dart
final colors = AuraThemeColors.of(context);
// colors.background, colors.accent, etc.
```

### How to toggle theme
```dart
AuraThemeProvider.of(context).toggleTheme();
// or
AuraThemeProvider.of(context).setThemeMode(ThemeMode.light);
```

### Rules
- Default mode: **Dark** (matches the original brand identity).
- The `AuraThemeColors` resolver is the **only** place where dark/light branching occurs.
- Widgets must never check `Theme.of(context).brightness` directly — use `AuraThemeColors.of(context)`.
- The Settings → Appearance section provides the user toggle.
- Future: persist the user's choice via `shared_preferences` (not yet implemented).

---

## 9. Haptic Feedback

| Action                          | Haptic                            |
|---------------------------------|-----------------------------------|
| Menu button tap                 | `HapticFeedback.lightImpact()`    |
| Mic button tap                  | `HapticFeedback.mediumImpact()`   |
| Drawer item tap                 | `HapticFeedback.selectionClick()` |
| Theme toggle                    | `HapticFeedback.selectionClick()` |

### Rules
- Use `lightImpact` for navigation actions.
- Use `mediumImpact` for primary actions (record/stop).
- Use `selectionClick` for settings toggles and menu items.
- Never use `heavyImpact` — it feels jarring.

---

## 10. File Structure

```
lib/
  main.dart                          # App entry, theme wiring
  theme/
    aura_tokens.dart                 # Spacing, radii, elevation, motion, typography
    aura_theme.dart                  # Colors, ThemeData builders, AuraThemeColors
    theme_provider.dart              # ThemeNotifier + AuraThemeProvider
  screens/
    initial_animation.dart           # Splash screen
    home_screen.dart                 # Main recording screen
    placeholder_screen.dart          # Settings, Recordings, Profile, etc.
```

### Rules for new screens
1. Import `../theme/aura_theme.dart` and `../theme/aura_tokens.dart`.
2. Resolve colors with `final colors = AuraThemeColors.of(context);` at the top of `build()`.
3. Use `AuraTypography.<style>(colors.textPrimary)` for text.
4. Use `AuraSpacing` for all padding/margin values.
5. Use `AuraRadius` for all border radii.
6. Use `AuraElevation` for all box shadows.
7. Wrap interactive elements in `Material` + `InkWell` for splash feedback.
8. Add appropriate `HapticFeedback` calls.
