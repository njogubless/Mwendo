# Mwendo Design System

Implemented in `app/lib/core/theme/` and `app/lib/core/widgets/`. You can view it live at `/dev/gallery` (debug builds).
The source is the Stitch DESIGN.md **prose** palette, reconciled for contrast (D-002, D-003). See
[stitch-analysis.md §4](stitch-analysis.md) for why the Stitch YAML/HTML values were not used.

**Character:** calm, warm, premium, human. Depth comes from tonal layers, not shadows. There are no gradients-as-decoration,
no neon, and no red for "missed".

## Colour (`MwColors`, light / dark)

| Token | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F7F4EE` Ivory | `#121314` | Page background |
| `sunken` | `#EFEBE1` Sand | `#0B0C0D` | Inputs, progress beds, secondary buttons |
| `surface` | `#FFFFFF` Ceramic | `#1C1D1F` | Cards |
| `surfaceWarm` | `#FAF8F4` Cream | `#232426` | Alternate card |
| `border` / `hairline` | `#E8E3D7` / 6% charcoal | `#2E2F31` / 8% ivory | Enclosures, dividers |
| `textPrimary` / `Secondary` / `Tertiary` | `#111315` / `#4A4D52` / `#6E7178` | `#F2EFE8` / `#BDB9B0` / `#8F8C85` | Tertiary darkened from Stitch `#787B82` for AA on ivory |
| `action` (+`onAction` white) | `#245C4A` Forest | `#2F7A61` | **Primary buttons**, selected states. White text ≈ 7.8:1 |
| `accent` (+`onAccent` charcoal) | `#D49A45` Ochre | `#E0AE62` | Progress, highlights, energetic CTAs. **Never white text on ochre** (≈2.5:1) |
| `accentText` / `accentTint` | `#8A5A12` / `#F6E7CF` | `#E8BC78` / `#3A2E1C` | Ochre text on light surfaces; warm context cards |
| `success` / `successTint` | Forest / `#DCEBE3` | `#6DB89A` / `#1F3A31` | Completion, supportive banners |
| `gentle` / `gentleTint` | `#C86D51` Terracotta / `#F7E3DB` | `#E08A6E` / `#3D2620` | Gentle attention and form errors. Used sparingly |
| `sage`, `sand` | `#98A896`, `#E6DFC8` | muted | Data visualisation only |
| `danger` | `#A63D2A` | `#E5806B` | Destructive actions only (delete account). **Never for missed activities** |

## Typography
Plus Jakarta Sans (bundled, OFL) at weights 400/500/600/700. The Stitch scale maps onto Material roles in `app_theme.dart`:
display 34/44, headline 32/26/22, title 18, body 17/15/13, label 14/12/11. Letter-spacing is defined in em and converted.
Uppercase is reserved for `labelSmall` micro-labels (`SectionLabel`).

## Space, shape, elevation, motion (`mw_tokens.dart`)
- **Space:** 4, 8, 16, 24, 40. Page margins are 20 (compact), 32 (medium) and 48 (expanded). Card padding is 20.
- **Radii:** 8, 12, 16 (buttons and inputs), **20 (cards)**, 24 (sheets), 28 (dock), and pill.
- **Breakpoints:** compact < 600 → floating dock. Medium < 1024 → navigation rail. Expanded → sidebar. Content is capped at 1200.
- **Shadows:** `resting` (cards) and `floating` (dock, sheets), both warm (`#241C15`) and diffuse.
- **Motion:** `Cubic(0.2, 0.8, 0.2, 1)` at 150/250/500ms. Press scale is 0.98.

## Components

| Widget | Notes |
|---|---|
| `MwCard` | tones `elevated`, `sunken`, `supportive`, `warm`. Optional `onTap` adds press feedback and button semantics |
| `MwButton` | variants `primary`, `accent`, `secondary`, `text`. Sizes 48/40. Supports `isLoading` (blocks taps, announces "in progress") |
| `StatusPill` | tones `neutral`, `success`, `accent`, `gentle` |
| `ProgressRing` | animated, clamped 0–1, announces a % value. `semanticLabel` is required |
| `SegmentedStrand` | multi-tone progress. `semanticLabel` is required, since colour is never the only signal |
| `MwToggle` | 48px hit area, toggled semantics |
| `SectionLabel` | uppercase micro-label with header semantics |
| `LoadingView` / `EmptyView` / `ErrorView` / `OfflineBanner` | the standard non-happy-path states |
| `MwPage` / `MwPageHeader` | responsive margins, max width, dock clearance |
| `BrandMark` / `BrandLockup` | the Stitch emblem, from `assets/images/mwendo_mark.png`. Works on light and dark |
| `MwBottomDock` | frosted floating dock, part of `AdaptiveShell` |

## Voice
Use the terms Routine, Step, Start, Essential and Today's progress (D-004). Prefer phrases like "Keep moving", "Start small",
"That's enough for today" and "Your morning shifted by 45 minutes". Never use "failed", "behind", "overdue" or "don't break your streak".

## Known limitation
Material Symbols is a variable font, and Flutter's icon tree-shaking drops some of its glyphs. **Build releases with
`--no-tree-shake-icons`** (verified on web on 2026-09-26: without the flag, `check`, `add`, `star` and `play_circle` rendered blank).
