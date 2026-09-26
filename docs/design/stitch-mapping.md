# Stitch → Implementation Mapping

Legend: **Designed** means there is a Stitch screen. **Needs design** means we must design it. Proposals are in [stitch-analysis.md §9](stitch-analysis.md).

## Designed screens

### S-TODAY → Today
| Stitch element | Product feature | Flutter | Backend/API |
|---|---|---|---|
| Greeting and date | Personal context | `TodayScreen` › `TodayHeader` | `GET /me/` (name, timezone) |
| Flow State card | Daily progress | `DayProgressCard` (`ProgressRing`, `SegmentedStrand`) | `GET /days/{date}/` → `progress` |
| Minimum Day banner | Minimum Day (M5) | `ContextBanner` → `MinimumDaySheet` | `PATCH /days/{date}/ {mode:"minimum"}` |
| Immediate Cadence card | "What now?" focus | `FocusActivityCard`, `ProgressBed` | `GET /days/{date}/` → `focus` (server-selected current or next pending), `POST /completions/{id}/start|pause|complete|skip/` |
| *(missing)* Done / Partial | Completion | `CompleteSheet` (amount picker) | `POST /completions/{id}/complete/ {actual_value}` |
| *(missing)* Skip reason | Skip | `SkipSheet` | `POST /completions/{id}/skip/ {reason}` |
| Adaptive buffer chips | Running Late / Time Budget (M5) | `AdaptSuggestionCard` → route `/today/adapt/:instanceId` | `…/adaptation/preview/` |
| Atmosphere photo | — | **Removed from Today** (proposal) | — |
| Today's Sequence | Day timeline | `DaySequence` › `TimelineItem` (states: done, partial, in progress, upcoming, skipped, cancelled) | same day payload |
| Reflection quote on item | Reflection | `TimelineItem` subtitle, `ReflectionSheet` | `POST /reflections/` |
| Reorder | Reorder today | deferred (M5+) | — |
| Principle card | Encouragement | `PrincipleCard` (static copy, optional) | — |
| Dock | Navigation | `AdaptiveShell` / `MwBottomDock` | — |

### S-ROUTINES → Routines
| Stitch element | Product feature | Flutter | Backend/API |
|---|---|---|---|
| Weekly vitality card | Consistency summary | `RoutinesSummaryCard` (M6 data, placeholder copy until then) | `GET /insights/consistency/` (M6) |
| Filter chips | Filter by category | `FilterChipRow` | `GET /routines/?category=` |
| Routine card (featured and compact) | Routine overview | `RoutineCard` with `StatTile`, `SequencePreview`, `MwToggle` | `GET /routines/`, `PATCH /routines/{id}/ {status}` |
| Initiate Cadence | Start now | `RoutineCard` action | `POST /routines/{id}/start/` |
| Edit Sequence / chevron | Edit routine | route `/routines/:id` → `RoutineEditorScreen` | `GET/PATCH /routines/{id}/` |
| Sequence Builder | Manage steps | `RoutineEditorScreen` › `StepList` (`ReorderableListView`) › `StepTile` | `…/activities/`, `…/activities/reorder/` |
| ★ essential toggle | Minimum Day essentials | `StepTile` | `PATCH …/activities/{aid}/ {is_essential}` |
| Add Step | New activity | `ActivityEditorSheet` (**needs design**) | `POST …/activities/` |
| Create New Rhythm | New routine | route `/routines/new` | `POST /routines/` |

### S-ADAPT → Adjust Routine (Running Late / Time Budget)
| Stitch element | Product feature | Flutter | Backend/API |
|---|---|---|---|
| Re-calibration card | Explain the context | `AdaptContextCard` (copy per trigger) | preview → `context` (late_by, finish_by) |
| Time budget pills | Time Budget | `SegmentedPills` + custom dialog | preview `{budget_minutes}` |
| Adapted Flow list | Compressed plan | `AdaptedActivityRow` (new / was) | preview → `items[]` |
| Rhythm preservation | Essentials retained | `SegmentedStrand` | preview → `essentials_kept` |
| Minimum Day Protocol | Minimum Day | `MwToggle` + essentials preview | preview `{mode:"minimum"}` |
| Start Adapted Routine | Apply | `PrimaryButton` | `…/adaptation/apply/` → `Adjustment` |
| Restore original | Revert | confirm dialog | `POST /adjustments/{id}/revert/` |
| Philosophy photo | — | removed or replaced with the text principle card | — |

## Screens without design (to design next)

| Screen | Feature | Flutter route | API |
|---|---|---|---|
| Splash | App start and session restore | `/` | `POST /auth/refresh/` |
| Welcome | Brand intro | `/welcome` | — |
| Register / Login / Forgot / Reset | Auth | `/auth/*` | `/auth/*` |
| Onboarding: Goals | Focus areas | `/onboarding/goals` | `PUT /me/preferences/` |
| Onboarding: Ideal day | Ideal day | `/onboarding/ideal-day` | same |
| Onboarding: Structure | Loose / balanced / structured | `/onboarding/structure` | same |
| Onboarding: Start time | Wake time and day start | `/onboarding/start-time` | `PATCH /me/` |
| Onboarding: Your first routine | Review and edit the generated routine | `/onboarding/routine` | `POST /routines/generate/` → `POST /routines/` → `POST /me/onboarding/complete/` |
| Goals list / detail / editor | Goals | `/goals`, `/goals/:id`, `/goals/new` | `/goals/*`, `/habits/*` |
| Insights | Consistency and trends | `/insights` | M6 |
| Profile / Settings | Account, time zone, day start, sign out | `/profile` | `/me/` |
| Complete / Partial / Skip / Reflection sheets | Completion | modal sheets | `/completions/*`, `/reflections/` |
| Recovery welcome-back | Recovery Mode | `/today` variant | M5 |
| Empty, error and offline variants | All | shared widgets | — |
