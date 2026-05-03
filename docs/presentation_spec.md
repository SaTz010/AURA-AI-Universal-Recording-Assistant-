# AURA — Presentation Specification

**Project:** AURA (AI Universal Recording Assistant)
**Deliverable:** 12-slide college FYP presentation deck
**Total runtime:** ~10–12 minutes, demo-led
**Style:** Minimalist, dark theme, premium-feel

This document is structured so a designer can produce the final deck without further input. Every slide includes: **purpose, visual structure, exact text content, layout placement, typography, colour, motion, and notes.** The brand visual system is locked at the top so every slide is consistent.

---

## 0. Brand Visual System (apply globally)

### Colour palette (mirror the AURA app's dark theme)

| Token | Hex | Usage |
|---|---|---|
| Background | `#0A0B0E` (Space Dark) | Slide background |
| Surface | `#16181D` (Charcoal) | Cards, elevated panels |
| Surface elevated | `#1F222A` | Inner cards, code blocks |
| Border | `#262A33` (Cool Grey @ 25%) | 1 px strokes, dividers |
| Text primary | `#F4F6FA` (Frost) | Headings, key data |
| Text secondary | `#A0A6B3` (Muted Grey) | Body, descriptions |
| Text tertiary | `#6E7480` (Cool Grey) | Captions, metadata |
| **Accent** | `#9FD8FF` (Ice Blue) | Highlights, icons, key numbers, emphasis |
| Accent soft | `#9FD8FF @ 12% alpha` | Halos, subtle backgrounds |
| Destructive | `#CF6679` | Negatives, warnings (rarely used in deck) |

**Light-mode variant exists** but the entire deck must use the dark theme. AURA is dark-first.

### Typography

- **Display / hero:** Poppins SemiBold, 56–72 pt, letter-spacing -1
- **Section title:** Poppins SemiBold, 36–44 pt, letter-spacing -0.5
- **Body / bullet:** Poppins Regular, 20–24 pt, line-height 1.5
- **Caption / metadata:** Poppins Regular, 14–16 pt, letter-spacing 1, ALL CAPS for labels
- **Code / mono:** JetBrains Mono Medium, 16–18 pt, accent colour for keywords

### Layout grid

- 1920 × 1080 px slide canvas, 16:9
- 96 px outer margin (left/right)
- 64 px outer margin (top/bottom)
- 12-column grid, 24 px gutter
- Vertical rhythm: 8 px baseline grid

### Visual primitives

- Cards: `12 px` radius, 1 px `border` stroke, no shadow (flat — like the AURA app)
- Icons: outline / rounded variants, 1.5 px stroke, accent colour
- Connectors / arrows: 2 px stroke, accent colour, rounded line caps, no arrow heads (use small dots instead)
- Charts / diagrams: monochrome with single accent colour, no gradients, no drop shadows

### Motion (subtle, only if the deck supports animation)

- Slide transition: simple fade, 300 ms
- On-slide reveal: bullet-by-bullet, 80 ms stagger, fade + 8 px upward translate
- No spinning, bouncing, or 3D effects

---

## Slide 1 — Title

**Purpose:** Establish identity. One unforgettable frame.

**Visual structure**
- Centered vertically and horizontally.
- Logo / wordmark "AURA" in display weight, 88 pt, accent colour.
- 2 px horizontal accent line, 64 px wide, directly under the wordmark.
- Tagline below the line.

**Text content**

```
AURA
─────
AI Universal Recording Assistant

Voice memos that summarise themselves.

— Sanskar [Last Name]
   [College / Department], [Date]
```

**Layout**
- Wordmark centered, vertical position 42% from top.
- Accent line and tagline immediately follow.
- Author/date at bottom-centre, 64 pt margin from bottom edge, text tertiary colour.

**Typography**
- AURA: 88 pt, accent colour `#9FD8FF`
- Tagline: 24 pt, text secondary
- Author/date: 16 pt, text tertiary

**Notes**
- Background: pure `#0A0B0E`. No imagery, no gradient. The minimalism is the statement.

---

## Slide 2 — The Problem

**Purpose:** Hook the audience with a shared frustration before showing the solution.

**Visual structure**
- Three short statements stacked vertically, each accompanied by a small outline icon to the left.
- Heavy whitespace above and below.

**Text content**

```
THE PROBLEM

People record everything.

— meetings, lectures, voice notes, doctor visits

Listening back is slow.
Transcribing is tedious.
The audio captures everything but surfaces nothing.
```

**Layout**
- Section label "THE PROBLEM" at top-left, caption type, ALL CAPS, accent colour.
- Three lines stacked, each 32 pt body weight, line-height 1.6.
- Center-left aligned at 96 px from left margin. Right half is empty.

**Typography**
- Caption: 16 pt, accent
- Lines: 32 pt regular, primary text

**Notes**
- The right-half emptiness is deliberate — visual breathing room.
- Spoken anecdote here. Slide says nothing more.

---

## Slide 3 — The Concept

**Purpose:** Compress AURA's pitch into one frame.

**Visual structure**
- Three large icon-circles in a horizontal row, connected by simple arrows (or just spaced dots).
- Single line of text below.

**Text content**

```
🎙       →       ✦       →       📄

Record.    Summarise.    Done.

AURA listens to your audio
and gives back a clean transcript and a focused summary.
```

**Layout**
- Three 96 px circles, accent stroke, evenly distributed across centre row.
- Word labels under each circle, 28 pt.
- Tagline (2 lines) at 64 px below the row, centered, text secondary.

**Typography**
- Step labels (Record / Summarise / Done): 28 pt SemiBold, primary text
- Tagline: 22 pt regular, line-height 1.5, text secondary

**Notes**
- The three-step compression is the *whole pitch*. Everything that follows refines it.

---

## Slide 4 — What AURA Is

**Purpose:** Show the four-tab structure at a glance. No app screenshots yet.

**Visual structure**
- Horizontal flow of four labeled boxes representing the four tabs.
- Below each box, a one-line description of what that tab does.

**Text content**

```
WHAT AURA IS

[ Home ]      [ Recordings ]      [ Summarize ]      [ Profile ]

record /     play / manage      AI summary +       stats /
upload                          full transcript    account
```

**Layout**
- Section label top-left.
- Four boxes evenly distributed across slide width. Each box: 280 × 100 px, surface colour, 1 px border, 12 px radius. Tab name centered inside, 24 pt SemiBold.
- Beneath each box, a 2-line description in caption type, text secondary, centered. 24 px gap between box and description.
- Subtle 2 px accent line connecting all four boxes to suggest sequence (left-to-right).

**Typography**
- Section label: 16 pt all-caps accent
- Tab name: 24 pt SemiBold primary
- Tab description: 16 pt regular text secondary

**Notes**
- This is structural, not decorative. Reviewers immediately understand app scope.

---

## Slide 5 — Improvement (The Differentiator)

**Purpose:** Show that the project's positioning was deliberate. This is the most important non-demo slide.

**Visual structure**
- Three-column comparison table.
- Centre column (AURA) is visually emphasised: accent border, slightly elevated background.

**Text content**

```
HOW AURA IS DIFFERENT

NATIVE VOICE       GENERIC                 AURA
RECORDER           TRANSCRIPTION

Records audio      Transcribes only        Records, transcribes,
                                           summarises in one app

Files pile up,     No context              Category-aware:
no structure       awareness               lecture, meeting, medical

Lives on the       Lives on a              Mobile-first.
phone              desktop                 Background-capable.
```

**Layout**
- Section label top-left.
- Three columns, each 480 px wide, 24 px gutter.
- Header row: column titles (NATIVE VOICE RECORDER / GENERIC TRANSCRIPTION / **AURA**) in caption case, 16 pt accent for AURA, 16 pt text tertiary for the other two.
- Three rows of comparison content, each row with a 1 px border separator.
- Centre column has a 2 px accent border, surface elevated background, 12 px radius — visually pops.

**Typography**
- Column headers: 16 pt SemiBold, accent for centre, tertiary for outer
- Row content: 18 pt regular, primary for centre column, text secondary for outer columns

**Notes**
- This slide should be lingered on for ~30 seconds. It's where reviewers form their opinion of project ambition.

---

## Slide 6 — Demo

**Purpose:** Hand off to live demonstration.

**Visual structure**
- Single word, oversized, centered.
- Blank everything else.

**Text content**

```
DEMO
```

**Layout**
- "DEMO" at 144 pt, accent colour, dead-centre of slide.
- Below, in 18 pt text tertiary: *"Live walkthrough on a real device."*

**Typography**
- DEMO: 144 pt SemiBold, accent
- Subtitle: 18 pt regular, tertiary

**Notes**
- Backup plan: have an embedded 90-second screen recording ready on a duplicate of this slide marked **"DEMO (recorded)"**. Switch to it only if live device fails.

### Demo script (for the speaker — not on the slide)

90 seconds, in this exact order:

1. **(15 s)** Tap the mic on Home → record 8 seconds of yourself saying "this is a test recording for my presentation" → tap Stop → name it.
2. **(15 s)** Open Recordings tab → expand the new tile → tap play → pause.
3. **(20 s)** Open Summarize tab → "From AURA" → pick the recording → choose category "Lecture" → tap Continue → show the analyzing screen briefly.
4. **(20 s)** Land on the summary detail screen → swipe through transcript + summary → open the 3-dot menu → show Share and Export PDF.
5. **(10 s)** Open Profile → show stats card and "summaries this month" highlight.
6. **(10 s)** Open Settings → show Storage and Notifications screens to demonstrate polish depth.

Total: ~90 seconds. **Practice this twice before presenting.**

---

## Slide 7 — Architecture

**Purpose:** Technical anchor. This is where engineering depth is judged.

**Visual structure**
- Three vertically-stacked blocks representing client, backend, and AI services.
- Connecting arrows labelled with the protocol used.
- Right side shows three small "supporting service" badges.

**Text content**

```
TECHNICAL IMPLEMENTATION

┌───────────────────────────────────────────┐
│         Flutter app (Android + iOS)        │
│   Auth · Recording · Summarisation flow    │
└───────────────────────────────────────────┘
                     │
                     │  HTTPS multipart
                     ▼
┌───────────────────────────────────────────┐
│        FastAPI backend (Render.com)        │
│             POST /process-audio            │
└───────────────────────────────────────────┘
                     │
              ┌──────┴──────┐
              ▼             ▼
       ┌──────────┐   ┌──────────┐
       │ Whisper  │   │   LLM    │
       │ transcribe│   │ summarise│
       └──────────┘   └──────────┘
```

**Right rail — supporting tech badges**

```
Firebase Auth
SharedPreferences (theme + prefs)
flutter_foreground_task (background recording)
```

**Layout**
- Section label top-left.
- Diagram occupies left two-thirds of slide. Each block: 720 px wide, 120 px tall, surface colour, 1 px border, 12 px radius.
- Vertical arrows: 2 px accent stroke, 64 px tall.
- Whisper / LLM blocks at the bottom: 320 px wide each, side-by-side under the FastAPI block.
- Right third: three small badges stacked vertically, each as a pill-shaped chip (16 px radius, surface elevated, 1 px border), 16 pt SemiBold text.

**Typography**
- Section label: 16 pt all-caps accent
- Block titles: 22 pt SemiBold primary
- Block subtext: 16 pt regular text secondary
- Arrow labels: 14 pt regular text tertiary
- Badges: 16 pt SemiBold

**Notes**
- The arrow connectors should be hand-drawn-style or simple straight lines — *not* shrinking-arrow flowchart shapes that look corporate.

---

## Slide 8 — Notable Engineering

**Purpose:** Demonstrate technical depth without being a code dump.

**Visual structure**
- Three horizontal cards stacked vertically (or arranged as 3-column row on widescreen).
- Each card has an icon, a title, and a one-line explanation.

**Text content**

```
ENGINEERING HIGHLIGHTS

▸  Background recording survives screen lock
   Android foreground service keeps the OS from killing the process.
   iOS UIBackgroundModes: audio handles the equivalent.

▸  Skeletal loading with 250 ms minimum-display
   Premium-feeling load states across Recordings, Summarize, Profile.
   The fix that flips an app from "amateur" to "shipped".

▸  Library-event pub/sub keeps four tabs in sync
   New recording on Home → Recordings tab + Summarize tab + Profile stats
   all refresh, no full rebuild needed.
```

**Layout**
- Section label top-left.
- Three cards, each full-slide-width, 200 px tall, 24 px gap between.
- Card layout: 64 × 64 icon on left (accent), title + body text to the right with 32 px padding.
- Card: surface colour, 1 px border, 12 px radius.

**Typography**
- Section label: 16 pt all-caps accent
- Card title: 24 pt SemiBold primary
- Card body: 18 pt regular text secondary, line-height 1.5

**Notes**
- Pick one of these to dive into when asked — most likely the background-recording one, since it's the most technically distinctive.

---

## Slide 9 — Implications: Personal

**Purpose:** Honest, reflective. Differentiates this from a typical tech demo.

**Visual structure**
- Three short personal statements, one per line.
- Visual treatment: minimalist, no icons, no cards. Just text on background, left-aligned.

**Text content**

```
WHAT I LEARNED

Built end-to-end for the first time —
mobile, cloud, and AI on a real product.

The gap between "works on emulator"
and "works on a friend's Samsung" is 80% of the work.

Shipped a beta to friends.
Their bug reports drove half of the polish.
```

**Layout**
- Section label top-left.
- Three statements stacked, each separated by 48 px.
- Left margin: 96 px. Right margin: 30% empty.
- Each statement: first sentence at 28 pt primary, follow-up sentence at 22 pt text secondary directly underneath.

**Typography**
- Section label: 16 pt all-caps accent
- Lead sentence: 28 pt SemiBold primary
- Detail: 22 pt regular text secondary

**Notes**
- This slide stops being about the project and starts being about the developer. Reviewers notice the shift.

---

## Slide 10 — Implications: World

**Purpose:** Position the project's relevance beyond your immediate scope.

**Visual structure**
- Three icon-led statements, one per row. Same minimalist treatment as Slide 9.

**Text content**

```
WHY IT MATTERS BEYOND ME

Accessibility
Hearing-impaired users get readable output.
Students with attention difficulties get summaries instead of 90-minute lectures.

Knowledge work
Professionals reclaim hours otherwise spent re-listening or re-typing.

AI summarisation is going mainstream
AURA shows the same capability fits in a pocket — single tap, no subscription friction.
```

**Layout**
- Section label top-left.
- Three rows. Each row:
  - Lead label (Accessibility / Knowledge work / AI mainstream) at 22 pt SemiBold accent.
  - Two-line body underneath at 20 pt text secondary.
- 56 px gap between rows.

**Typography**
- Section label: 16 pt all-caps accent
- Row label: 22 pt SemiBold accent
- Row body: 20 pt regular text secondary

**Notes**
- Connect this to a real news beat or trend if you can — "AI summarisation is going mainstream" is true and well-known, your project is timely.

---

## Slide 11 — Future Work + Recommendation

**Purpose:** Show you've thought past graduation. Two-column comparison: what could happen vs what you'd recommend.

**Visual structure**
- Two columns side-by-side, equal weight.
- Left column: "WHAT'S NEXT" (potential features).
- Right column: "WHAT I'D RECOMMEND" (advice on how to do them).

**Text content**

```
FUTURE WORK & RECOMMENDATIONS

WHAT'S NEXT                      WHAT I'D RECOMMEND

Plan-based limits + billing      Don't ship paid until plan-tier
                                 infrastructure is real.

FCM push for                     Decouple summarisation from
"summary ready"                  app foreground.

Auto language detection          Already supported by Whisper —
                                 UX work needed, not engineering.

On-device summarisation          Real privacy story; revisit when
                                 small LLMs are practical on phones.
```

**Layout**
- Section label spanning top-left.
- Two columns of equal width with a 1 px vertical accent divider between them.
- Each column: 4 rows. Each row: lead phrase + 2-line follow-up. Gap between rows: 40 px.
- Left column lead: text primary. Right column lead: accent.

**Typography**
- Section label: 16 pt all-caps accent
- Column headers: 18 pt all-caps text tertiary
- Lead phrases: 22 pt SemiBold (left primary, right accent)
- Follow-up text: 18 pt regular text secondary

**Notes**
- The right column is the *insight* — what to do, not what's possible. That's where you show maturity.

---

## Slide 12 — Thank You / Questions

**Purpose:** End cleanly. Open the conversation.

**Visual structure**
- Centered "Thank you" wordmark.
- "AURA" wordmark recapped in small text below.
- Contact details and "Questions?" prompt at bottom.

**Text content**

```
Thank you.


           AURA

       Questions?


   GitHub: github.com/[your-handle]/aura
   Email: abhidanthapa@gmail.com
```

**Layout**
- "Thank you." at 88 pt, primary text, centered, vertical position 30% from top.
- "AURA" at 28 pt accent below, with the same 64 px accent line separator from Slide 1.
- "Questions?" at 32 pt SemiBold, primary text, vertical position 60% from top.
- Contact details at 16 pt text tertiary, bottom-centered.

**Typography**
- "Thank you.": 88 pt SemiBold primary
- "AURA": 28 pt SemiBold accent
- "Questions?": 32 pt SemiBold primary
- Contact: 16 pt regular tertiary

**Notes**
- The accent line from Slide 1 returns — visual bookend. This signals "we're done" without saying it.

---

## Production checklist for the designer

| Item | Done? |
|---|---|
| Background colour `#0A0B0E` set on every slide | ☐ |
| Poppins font loaded, JetBrains Mono for code | ☐ |
| Accent `#9FD8FF` used consistently for emphasis only — never for body text | ☐ |
| Each slide has 1 idea max — no slide has more than 7 lines of text | ☐ |
| Slide 6 has both a live-demo card AND a backup recorded-video card | ☐ |
| Slide 7 architecture diagram drawn at 1:1 (not raster-scaled) | ☐ |
| Slide 5 comparison table — centre column visually emphasised | ☐ |
| All bullet points removed in favour of clean prose where possible | ☐ |
| No drop shadows, no gradients, no 3D effects, no rotated text | ☐ |
| Slide numbering / footer kept off slides (or 12 pt tertiary, bottom-right corner only) | ☐ |
| All slide transitions: 300 ms fade, no spinning | ☐ |
| Final deck exported as a single PDF for backup, plus the editable source file | ☐ |

---

## Non-content design principles (lock these in)

1. **Negative space is content.** Every slide should feel airy. If text fills more than 60% of the slide area, cut something.
2. **One accent colour, deployed sparingly.** Accent draws the eye; if it's everywhere, nothing stands out.
3. **No emoji icons in actual deck slides.** This document uses 🎙 ✦ 📄 to communicate quickly to the designer — they should be replaced with proper outline icons (Material Symbols or Lucide).
4. **Consistent slide identity.** Every slide opens with the same caption-style label at top-left in accent. This anchor builds reading muscle memory.
5. **Avoid screenshots without context.** App screenshots should appear only on Slide 6's backup recording. The deck talks about AURA; the demo *is* AURA.
6. **No filler slides.** No "agenda", no "thank you for listening" interrupting the flow, no "questions" before the actual end.

---

## Speaker support material (not part of the deck)

These are for the speaker, not visible to the audience:

1. **Speaker notes** — under each slide, paste a 2-sentence prompt. Use it the morning of the presentation, then throw it away. Don't read from notes during delivery.
2. **A device demo backup video (90 s)** — recorded from your phone in advance, no commentary, dark theme, real-time pace. This sits as Slide 6.5 hidden in the deck.
3. **A printed one-page handout** (optional) — half-letter, summarising the project. Useful if reviewers ask for "documentation" after.

---

## Final word

This deck is **12 slides, ~10 minutes, demo-led**. The visual system is locked, every slide has a single purpose, and nothing is ornamental. The only deviations from this spec should be in icon choice and layout micro-tuning — not structure or content.
