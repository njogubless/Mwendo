# Stitch Export Analysis

Source: `stitch/` (three exports, analysed 2026-09-26).

| Folder | Screen | Contents |
|---|---|---|
| `stitch_mwendo_adaptive_daily_routine` | **Today** | `code.html`, `screen.png`, `DESIGN.md` |
| `stitch_mwendo_adaptive_daily_routine_2` | **Routines** (list + inline Sequence Builder) | same |
| `stitch_mwendo_adaptive_daily_routine_3` | **Running Late / Time Budget adaptation** (titled "Routine Flow Detail") | same |

The three `DESIGN.md` files are byte-identical (md5 `7506e504…`). No local image assets: the logo and photos are
hot-linked `lh3.googleusercontent.com` URLs, and the pages load Tailwind from its CDN plus Google Fonts.

The design only covers these 3 screens. Everything else in the MVP (auth, onboarding, goals, insights, profile,
sheets and dialogs, empty, error and offline states) has **no design**. See §9.

---

## 1. Screens

### 1.1 Today (`S-TODAY`)
Top to bottom:
1. **App bar**: brand emblem, "MWENDO" micro-label, and the title "Today". Avatar on the right. Frosted and fixed.
2. **Greeting**: date micro-label ("TUESDAY · SEPTEMBER 26"), "Good morning, Zawadi", and a `tune` icon button (quick settings).
3. **Day progress card ("Flow State")**: "68% of today's cadence", "4 of 6 intentional rituals fulfilled", a circular
   gauge, a segmented strand (completed in green, in progress in ochre, remaining in grey), "Grounded momentum", and "2 remaining".
4. **Minimum Day banner**: "Feeling low energy? Switch to 'Minimum Day' (13 min essentials)" with an **Activate** button.
5. **Focus card ("Immediate Cadence")**: the product's core answer to *what should I do now*. Status pill
   "NOW · IN PROGRESS", "8 min left", title with an emoji, a description, a progress bed ("12 mins completed / 20 mins target"),
   a **Continue Session** button (primary, green), and **Pause Pace** and **Graceful Skip** (secondary).
6. **Adaptive buffer card**: "Schedule shifted unexpectedly?" with chips *Running 15m Late*, *Tight Work Day (−30m)*
   and *Shift Deep Work*.
7. **Atmosphere photo card**: a decorative quote over a photo.
8. **Today's Sequence**: a vertical timeline of 8 items across routines. States: *fulfilled* (green check, optional
   reflection quote), *in motion* (ochre ring with a spinning icon and a left accent border), *upcoming*, and *deep block* with a
   "High Agency" tag. There is also a "Reorder" link.
9. **Principle card**: a quote.
10. **Bottom dock**: Today · Routines · Goals · Insights · Profile.

### 1.2 Routines (`S-ROUTINES`)
1. App bar ("Routines").
2. Editorial header: "HARMONIC LIFE FLOW / My Routines / Rhythms designed around your life cycles…" and a `tune` button.
3. **Weekly vitality card**: "88% Aligned", "3 active cadences", and a decorative gradient wave (SVG).
4. **Filter chips**: All Rhythms (3) · Morning · Deep Work · Evening · Rest (scroll horizontally).
5. **Routine cards** (3 variants) with a coloured left accent (green, ochre, terracotta), name, tag (Active / High Vitality /
   Restorative), schedule line, **active toggle**, two stat tiles (span, consistency or safety net), and a footer:
   - Featured: an icon *sequence preview* ribbon, "Minimum Day: 3 key steps", **Edit Sequence** and **Initiate Cadence**.
   - Compact: a sub-block summary and a chevron.
6. **Sequence Builder** (inline under the list): drag handles, icon, title, description, duration chip, and a **★ toggle** that marks
   the step as a Minimum Day essential. Also "Add Step to Cadence" and "45m total".
7. **Create New Rhythm**: full-width ochre button.
8. Bottom dock.

### 1.3 Running Late / Adapted Flow (`S-ADAPT`)
1. App bar with a back arrow and the title "Routine Flow Detail".
2. **Context card** (warm tint): "GENTLE RE-CALIBRATION / You're running 45 minutes behind. / Life happens… re-balanced
   your flow so you arrive calm for your 09:00 AM team sync."
3. **Time budget selector**: 15 min · **30 min (Recommended)** · 45 min · 1 hour · Custom.
4. **Adapted Flow card**: "30m, was 90m", "9:00 AM target strictly guarded". Each row shows an icon, a title, a tag (Essential /
   Focus Core / 80/20 Peak), a description, the new duration, and the struck-through original duration.
5. **Rhythm preservation** strand: "5 of 5 core habits active".
6. Philosophy photo card.
7. **Minimum Day Protocol** card with a toggle. When on, it reveals "The 13-Minute Floor" (Water 1m, 3 Breaths 2m, Light Stretch 10m).
8. Floating footer: **Start 30-Minute Adapted Routine**, with a text link "Restore 90-minute schedule anyway".

---

## 2. Navigation

- **Primary**: a 5-tab floating pill dock: Today, Routines, Goals, Insights, Profile. The active tab uses the primary colour, a
  semibold label and a green dot indicator.
- **Secondary**: S-ADAPT is a pushed route (back arrow). It is reached from the Today adaptive-buffer chips and possibly
  from the Minimum Day banner.
- Tapping the avatar in the header duplicates the Profile tab (see §9).
- Desktop and tablet behaviour is described in DESIGN.md (a sidebar on desktop) but never drawn.

## 3. Reusable components (candidate Flutter widgets)

| Component | Seen in | Notes |
|---|---|---|
| `MwAppBar` (frosted, brand and title, avatar or back) | all | blur 16–20px, 85% surface |
| `MwBottomDock` | Today, Routines | floating 28px radius, blur, 16px above the safe area |
| `SectionLabel` (uppercase micro-label and trailing action) | all | `label-sm`, 0.04em |
| `MwCard` (surface, hairline, radius) | all | resting shadow |
| `ProgressRing` | Today | stroke 3.5/36 with rounded caps |
| `SegmentedStrand` (multi-tone bar) | Today, Routines, Adapt | completed, in progress and remaining segments |
| `ProgressBed` (label row and bar in a recessed box) | Today focus card | |
| `StatusPill` / `TagChip` | all | tonal variants: green, ochre, terracotta, neutral |
| `FilterChipRow` / `SegmentedPills` | Routines, Adapt | single-select, scrolls horizontally |
| `PrimaryButton`, `SecondaryButton`, `TextLinkButton` | all | 48px, press scale 0.98 |
| `MwToggle` | Routines, Adapt | custom pill switch |
| `TimelineItem` (rail, node state, card) | Today | 4 node states |
| `ActivityRow` (icon tile, title, tag, meta, duration and original duration) | Adapt, Builder | |
| `StepTile` (drag handle, icon, title, duration chip, ★) | Builder | |
| `IconTile` (rounded square or circle, tonal bg) | all | |
| `StatTile` (icon, label, value) | Routines | |
| `ContextBanner` (icon, title, body, action) | Today (Min Day), Adapt | |
| `QuoteCard` (text or image) | all | decorative, see §9 |

## 4. Design tokens — the source is internally inconsistent

`DESIGN.md` has **two palettes**. The YAML front-matter is a Material-3 generated scheme, and it is what the HTML uses.
The prose describes the intended brand palette. They differ noticeably, and the screenshots are rendered with the M3 one.

| Role | M3 YAML / HTML (rendered) | DESIGN.md prose (intended) | Recommendation |
|---|---|---|---|
| Canvas | `#F9F9FC` (cool grey-white) | Ivory `#F7F4EE` | **Prose**: warm off-white is part of the brief |
| Sunken | `#F3F3F6` / `#EEEEF0` | Sand `#EFEBE1` | Prose |
| Elevated | `#FFFFFF` | Ceramic `#FFFFFF` / Cream `#FAF8F4` | same |
| Text | `#1A1C1E` | Charcoal `#111315` | Prose |
| Text secondary | `#504537` | Slate `#4A4D52` | Prose |
| Text tertiary | `#827565` | Graphite `#787B82` | Prose |
| Primary (ochre) | `#825500` text/icons, container `#D49A45` | Ochre `#D49A45`, active `#B88032` | Ochre `#D49A45` for fills, and a darker ochre (`#8A5A12`-ish) for **text** on light surfaces (for contrast) |
| Secondary (green) | `#316856` | Forest `#245C4A`, active `#1A4436` | Prose |
| Tertiary | `#97472E` / `#ED8B6D` | Terracotta `#C86D51` | Prose, and use it sparingly |
| Data accents | — | Sage `#98A896`, Sand tint `#E6DFC8` | Prose |
| Borders | `outline-variant #D5C4B2` | hairline `rgba(17,19,21,0.06)` / `#E8E3D7` | Prose |
| Error | `#BA1A1A` | not specified | A muted brick tone, used rarely. The copy does the work (see principles) |

**Radii also conflict.** The DESIGN.md tokens are `lg=16px, xl=24px`, and the prose says cards are 20–24px. The HTML's Tailwind config
overrides them to `lg=8px, xl=12px`, which is what the screenshots show. Recommendation: follow the prose (cards 20px, inner controls
14–16px, pills full). This is the "smoothed pebble" identity the brief describes.

**Typography.** Plus Jakarta Sans throughout (400/500/600/700). The scale in YAML is consistent and adopted as-is:
display 44/34 (mobile), headline-lg 32/26 (mobile), headline-md 22, headline-sm 18, body 17/15/13, and label 14/12/11.

**Spacing.** A 4/8 rhythm. Margins are 20px (mobile), 32px (tablet) and 48px (desktop). Gutters are 16/24/32. The space scale is 4, 8, 16, 24 and 40.

**Elevation.** Tonal layering first. Resting shadow: `0 2 8 -2 rgba(36,28,21,.04)` + `0 1 3 0 rgba(36,28,21,.02)`.
Floating shadow: `0 12 32 -4 rgba(36,28,21,.08)` + `0 4 12 -2 rgba(36,28,21,.03)`. Blur of 16–20px on overlays.

**Motion.** Press scale 0.98 with `cubic-bezier(0.2, 0.8, 0.2, 1)`. Check-ring "organic fill" to green on completion.
The progress bar animates width over 500ms. A pulse dot marks "right on schedule". Spinning icons appear on in-progress nodes (see §9).

**Icons.** Material Symbols Outlined (weight 400, some filled). Used: `tune, vital_signs, check_circle, energy_savings_leaf,
play_circle, play_arrow, pause, forward, auto_fix_high, schedule, compress, swap_vert, spa, water_drop, directions_run,
restaurant, psychology, wb_sunny, menu_book, bedtime, filter_vintage, radio_button_checked, view_timeline, flag, insights,
account_circle, person, self_improvement, shower, local_cafe, timelapse, verified, workspace_premium, temp_preferences_custom,
drag_indicator, star, star_border, add, add_circle, chevron_right, reorder, arrow_back, fitness_center, blender, check,
progress_activity`.

## 5. States present in the design

- Activity: fulfilled (with an optional reflection), in progress, upcoming, high-priority upcoming.
- Routine: active or paused (toggle), and a category tag.
- Adaptation: budget selected, Minimum Day on or off, CTA "preparing…" then "ready".
- Minimum Day banner: inactive and active ("Active ✓", terracotta).

## 6. Interactions (from the HTML scripts)

- Minimum Day toggle on Today. **The demo script bumps the focus-card progress bar from 60% to 85% when it activates.** That is wrong
  behaviour: switching mode must not fake progress. The Flutter implementation must not copy it.
- Filter chips: single-select.
- Routine active toggle.
- "Edit Sequence" scrolls to the inline builder.
- "Add Step" appends a hardcoded step. The real flow needs an activity editor.
- Budget pills recompute the total and the CTA label. Minimum Day overrides the budget (13m). "Custom" makes the CTA read "Configure Custom Flow".
- The "Restore original" link raises an `alert()`. It needs a real confirm dialog.
- Drag to reorder is implied (`drag_indicator`, `cursor-grab`) but not implemented.

## 7. Responsive behaviour

The HTML is mobile-only (`max-w-md` dock, a single column, `min-height: 884px`). DESIGN.md describes:
- < 768: 4 columns, 20px margins, bottom dock.
- 768–1024: 8 columns, two-column dashboard (progress and focus next to the timeline).
- > 1024: 12 columns capped at 1200px, sidebar navigation.
None of this is drawn. We will implement breakpoints with `LayoutBuilder` and adaptive navigation: dock → rail → sidebar.

## 8. Assets

| Asset | Status |
|---|---|
| Brand emblem ("M" mark, ochre/green) | Downloaded from the Stitch export and stored at `app/assets/images/mwendo_mark.png` (512px source, cropped). An SVG would still be better for launcher icons. |
| Photos (veranda, tea cup) | Remote, generated, unlicensed. **Do not ship.** |
| Font | Plus Jakarta Sans (OFL). Bundle it locally so it works offline. |
| Icons | Material Symbols. Use the `material_symbols_icons` package. |

---

## 9. Gaps, contradictions and recommended changes

These need a decision before or during the relevant milestone. The **bold** items affect product behaviour, not only visuals.

### 9.1 Missing screens and states (no design exists)
1. Splash, Welcome, Register, Login, Forgot or reset password.
2. The onboarding flow: goals, ideal day, structure preference, day start time, and a generated-routine review.
3. Goals list, goal detail with progress, and goal editor.
4. Insights, Profile and Settings.
5. **Routine editor** as its own screen (name, schedule, category, finish-by time) and an **activity editor** (title, icon,
   target, minimum version, essential ★, linked habit).
6. **Completion sheet**. The focus card has *Continue / Pause / Skip* but **no "Done" and no "Done partly"**. Partial completion
   is a core principle and has no entry point. Recommendation: the primary button changes by state (*Start* → *Mark done*), and
   there is a secondary "Log partial" with a quick amount picker ("12 of 20 min").
7. **Skip sheet**: optional reason chips (no time, low energy, not relevant today, other), and "move to later" if possible.
8. **Reflection capture**. The timeline shows "Felt grounded and present", but nothing in the design shows how the user enters it.
9. Empty states: no routines yet, nothing scheduled today (rest day), all done ("That's enough for today").
10. Loading, error and offline states for every screen.
11. **Recovery Mode**: returning after missed days. This is in the product brief but has no design.
12. Dark mode: not specified. Recommendation: define it in the design system and build it in M1, since light and dark tokens are cheap if done early.
13. Tablet and desktop layouts.

### 9.2 Contradictions with product principles
1. **"You're running 45 minutes behind."** This copy is banned by §21 ("You're behind"). Suggest: *"Your morning shifted by 45 minutes."*
2. **"2 remaining" in terracotta**. It reads as a warning. Use neutral text.
3. **The Minimum Day demo inflates progress** (§6).
4. The "88% Aligned" and "92% peak form" percentages show on day one with no data. Needs an empty or "building your rhythm" state.
5. The spinning `refresh` icon on the in-progress node is visually anxious, which runs against "calm". Suggest a gentle pulse ring or a static filled ring.
6. Decorative photo and quote cards sit **above** the day's sequence on Today. They push the core content down and add
   cognitive load. Suggest removing the photo card from Today (keep one small principle card at the end, optionally), or
   limiting it to empty or complete states. The photo prompts ("African courtyard with acacia trees") also lean toward the
   stereotyped imagery the brief rules out.

### 9.3 Vocabulary and clarity
The design uses many synonyms for one concept: *routine / rhythm / cadence / flow / ritual / sequence*. It also uses jargon: *High Agency,
80/20 Peak, Focus Core, Cellular Hydration, Initiate Cadence, Flow State, Harmonic Life Flow*. This fights "reduce cognitive load".
Recommendation: pick a single vocabulary, keep warmth in the tone rather than in the nouns, and use it everywhere
including the API:

| Concept | Use | Avoid |
|---|---|---|
| Routine | "Routine" | Rhythm, Cadence, Flow |
| Activity | "Step" (UI) / `Activity` (code) | Ritual, event, block |
| Start routine | "Start" | Initiate Cadence |
| Day progress | "Today's progress" | Flow State, cadence % |
| Essential step | "Essential" (★) | Focus Core, 80/20 Peak |
| Priority tag | "Priority" | High Agency, High Vitality |

### 9.4 Interaction ambiguities
1. **Today's sequence mixes activities from several routines.** Decide whether the timeline groups by routine or shows one merged
   chronological list. The recommendation is a merged list, sorted by scheduled time, with a subtle routine label on each item.
2. **"Reorder" on Today**: does it reorder today only, or the routine itself? Recommendation: today only. The routine is edited in Routines.
3. **The routine card toggle**: does it mean active/paused? Recommendation: "Active" means it is scheduled. Pausing keeps history. Archive lives in the overflow menu.
4. **"Initiate Cadence"** on a routine card starts a routine outside its schedule. We need to define whether that creates an ad-hoc instance for today (recommended: yes).
5. **Running Late**: how does the system know the user is "45 min behind" and when the "09:00 team sync" is? There is no Event or calendar model in the MVP.
   Recommendation for MVP: the routine gets an optional **finish-by time**, and "late by" is computed from now vs the routine's
   scheduled start. The user can always pick a budget manually. Calendar anchoring comes later.
6. **Time budget compression** needs per-activity data the design implies but doesn't name: **target duration**,
   **minimum duration**, **priority/essential**. These go into the activity editor.
7. The screen title "Routine Flow Detail" doesn't match its content. Suggest **"Adjust your morning"** (routine name), presented as a pushed route or a full-height sheet.
8. The adaptive buffer chip "Shift Deep Work" needs a definition. Suggest dropping it from the MVP. Keep "Running late" and "Less time today".
9. The header avatar duplicates the Profile tab. Suggest keeping the avatar only on wide layouts, or dropping it.
10. The focus card uses an emoji (🏃) while everything else uses Material icons. Use icons.

### 9.5 Accessibility
- **White text on ochre `#D49A45` has a contrast of ≈2.5:1, which fails WCAG AA** (the "Create New Rhythm" button). Use charcoal text on
  ochre (≈7.5:1), or use forest green for primary fills (white on `#245C4A` ≈7.8:1). Recommendation: green as the primary action colour
  (as the Today CTA already does), and ochre for highlights and progress.
- 11px `label-sm` in secondary colours is borderline. Keep it for micro-labels only.
- Truncated titles ("Cellular Hydra…", "Mobility & Caden…"). Allow two lines in rows.
- Touch targets: the ★ buttons (28px) and the timeline items need 44–48px hit areas.
- Custom toggles need semantics labels. Colour-only state (the segmented strand) needs a text equivalent.
