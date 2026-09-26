# Domain Model

Mwendo models *plans* and *what actually happened* as separate things. A routine is a template. Each day, templates
are turned into concrete occurrences, and every occurrence records its outcome. The history is never rewritten by later edits.

```
                 ┌──────────┐
                 │   User   │  timezone, day_start_time, preferences
                 └────┬─────┘
        ┌─────────────┼───────────────────────────────┐
        ▼             ▼                               ▼
     ┌──────┐     ┌───────┐   realised by    ┌──────────────────┐
     │ Goal │◄────│ Habit │◄─────────────────│ RoutineActivity  │  (template step)
     └──┬───┘     └───────┘   (optional)     └────────┬─────────┘
        │                                             │ belongs to (ordered)
        │ Measurement (manual progress)               ▼
        ▼                                        ┌─────────┐
  ┌─────────────┐                                │ Routine │ schedule, finish_by, status
  │ Measurement │                                └────┬────┘
  └─────────────┘                                     │ materialised per day
                                                      ▼
  ┌────────────┐  1 per user/day  ┌──────────────────────────┐
  │ DailyPlan  │─────────────────►│ RoutineInstance          │ mode, time_budget
  │ mode/energy│                  └────────────┬─────────────┘
  └────────────┘                               │ 1 per activity (snapshot)
                                               ▼
                                   ┌──────────────────────┐        ┌────────────┐
                                   │ ActivityCompletion   │◄───────│ Reflection │
                                   │ status/target/actual │        └────────────┘
                                   └──────────────────────┘
                                   ┌──────────────────────┐
                                   │ Adjustment           │ running late / budget / minimum day (audit + revert)
                                   └──────────────────────┘
Later: BehaviorPattern → Recommendation → Experiment; Notification; Task; Event
```

## Entities

### User
The owner of all data. Every other entity is scoped to exactly one user.
- `timezone` (IANA) and `day_start_time` (e.g. 04:00) define what "today" means. A user awake at 01:00 is still in
  yesterday's day if the day starts at 04:00. **All "today" logic uses the user's local date, computed server-side from these fields.**
- Preferences: structure preference (loose / balanced / structured), onboarding answers, and `onboarding_completed_at`.

### Goal
Something the user wants to achieve ("Read 12 books this year").
- It has an optional measurable target: `target_value` + `unit` + `target_date`. A goal can also be qualitative, with no target.
- Status: `active`, `paused`, `achieved`, `archived`.
- Progress is **derived** from linked habits' completions and/or manual **Measurements**. It is never stored as a mutable counter.

### Habit
A repeated behaviour that supports a goal ("Read 20 pages every evening").
- It optionally belongs to one goal.
- A habit is *performed* through one or more RoutineActivities. This link is how completion data rolls up into goal progress.
- A habit is not a checkbox. It has no completion state of its own.

### Routine
A named, ordered sequence of activities with a schedule ("Morning routine, Mon–Fri 07:00").
- `category` (morning, work, evening, rest, custom) drives the Routines filter chips.
- Schedule: days of week and start time. An optional `finish_by` time acts as the hard stop the Running Late adaptation protects.
- Status: `active` (scheduled), `paused` (kept but not scheduled), `archived` (hidden, history retained).

### RoutineActivity (UI: "Step")
One step in a routine template.
- `target_kind` is `duration`, `count` or `check`, with `target_value` + `unit` (e.g. 20 min, 20 pages, check).
- `minimum_value` is the smallest version that still counts ("10 min instead of 20"). Compression never goes below it.
- `is_essential` (★) means the step stays in Minimum Day.
- `priority` (`core`, `standard`, `optional`) sets the order in which steps are dropped under a time budget.
- Optional `habit` link.

### DailyPlan
The user's day. It exists so that day-level context has a home:
- `mode`: `normal`, `minimum`, `recovery`.
- `energy` (optional self-report).
- The day is the unit for "Today's progress".

### RoutineInstance
A routine as it happens on one date. It is created **lazily and idempotently** when the day is first requested,
and is unique per `(routine, local_date)`.
- `scheduled_start`, `status` (`planned`, `in_progress`, `done`, `partial`, `skipped`), and `time_budget_minutes` (when compressed).
- Ad-hoc instances ("Start now" on a routine outside its schedule) are allowed.

### ActivityCompletion
The occurrence of one activity inside a routine instance, and its outcome. Created as `pending` when the instance
materialises.
- **Snapshot fields** (title, icon, target, minimum, essential, position) are copied at materialisation, so editing or deleting
  the template never rewrites history.
- `planned_value` is the target *after* adaptation (e.g. 15 of 40 min). `target_value` is the original. `actual_value` is what happened.
- `completion_ratio` = actual / planned, clamped to 0–1. It is derived and stored for querying.
- Status: `pending`, `in_progress`, `completed`, `partially_completed`, `skipped`, `cancelled`.
  - `skipped` means the user chose not to do it. The reason is optional.
  - `cancelled` means the system removed it by adaptation (Minimum Day or a time budget), with user approval. It is **not** counted against the user.
- Timing: `scheduled_at`, `started_at`, `completed_at`, `paused_at`, `active_seconds` (supports Pause).

### Reflection
Optional context: a short note plus an optional mood or energy value, attached to a completion, a routine instance, or a day.

### Adjustment
A record of one adaptation applied to a day or instance: `running_late`, `time_budget`, `minimum_day` or `recovery`, with
parameters and a before/after summary. It makes adaptations **transparent and revertible** ("Restore 90-minute schedule"),
and it becomes input for insights.

### Measurement *(M4)*
A manual progress entry for a goal ("finished book 4").

### Later phases (documented, not built)
- **BehaviorPattern**: derived observations ("completes workouts 30% more before 8 AM").
- **Recommendation**: a suggested change with *what we noticed / suggestion / why*. States: `proposed`, `accepted`, `dismissed`.
  Accepting one applies a change to a routine. **Nothing changes a routine without acceptance.**
- **Experiment**: a time-boxed variant of a routine, with a hypothesis and a comparison window.
- **Task** (one-off) and **Event** (time-anchored, e.g. from a calendar). Event will eventually replace `finish_by` as the anchor for Running Late.
- **Notification**.

## Key rules (domain invariants)

1. All data is user-isolated. No cross-user references.
2. Template edits never modify existing ActivityCompletion rows. Pending rows for **today** are re-synced when a template is edited.
   Past and started rows are frozen.
3. `actual_value ≥ planned_value` → `completed`. `0 < actual < planned` → `partially_completed`. Partial always counts proportionally.
4. **Today's progress** = Σ completion_ratio over the day's completions, excluding `cancelled` / count excluding `cancelled`.
   `skipped` stays in the denominator at 0, and the UI shows it neutrally ("Skipped · that's okay"). *(Decision D-007, open for review.)*
5. Adaptations are computed by a pure, deterministic function (`plan_adaptation(instance, budget | late_by, mode) → proposal`).
   The proposal is previewed and then applied explicitly.
6. Minimum Day keeps only `is_essential` steps, each at `minimum_value`. The other pending steps become `cancelled`.
   It is reversible for pending items.
7. Streaks may be shown but are never the primary metric. Consistency (the share of scheduled days with any progress) is primary.
