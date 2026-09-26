# Data Model (PostgreSQL)

This is the physical schema for the MVP entities in [domain-model.md](domain-model.md). Conventions:

- Primary keys are UUIDv4 (`id`). They are safe to expose, and clients can generate them for offline creation later.
- Every table has `created_at` and `updated_at` (`timestamptz`).
- Every user-owned table has `user_id` FK → `accounts_user` and an index that leads with `user_id`.
- Soft deletion uses `archived_at` on user-curated entities (goals, habits, routines, activities). History tables
  (instances, completions, adjustments) are never soft-deleted. Account deletion hard-deletes everything (GDPR).
- Enums are `varchar` with Django `TextChoices` and a `CHECK` constraint. Timestamps are UTC. Local dates are `date`.

## accounts

**accounts_user** (custom `AbstractBaseUser`; email is the username)
| column | type | notes |
|---|---|---|
| id | uuid PK | |
| email | citext unique | login identifier |
| password | varchar | Django hasher (Argon2 preferred) |
| display_name | varchar(80) | |
| timezone | varchar(64) | IANA, default `UTC`, validated |
| day_start_time | time | default `04:00` |
| is_active, is_staff | bool | |
| onboarding_completed_at | timestamptz null | |
| date_joined | timestamptz | |

**accounts_preferences** (1:1 user)
`structure` (`loose|balanced|structured`), `wake_time` time, `focus_areas` text[], `ideal_day` jsonb (onboarding answers).

## goals

**goals_goal**
`user_id`, `title` (120), `description` text, `area` varchar, `target_value` numeric(10,2) null, `unit` varchar(32) null,
`target_date` date null, `status` (`active|paused|achieved|archived`), `achieved_at`, `archived_at`.
Index: `(user_id, status)`.

**goals_habit**
`user_id`, `goal_id` FK null (SET NULL), `title`, `frequency` jsonb (`{"per":"day"|"week","times":n}`), `archived_at`.
Index: `(user_id, goal_id)`.

**goals_measurement** *(M4)*
`user_id`, `goal_id` FK (CASCADE), `value` numeric, `recorded_on` date, `note`.

## routines

**routines_routine**
| column | type | notes |
|---|---|---|
| user_id | FK | |
| name | varchar(80) | |
| category | varchar | `morning|work|evening|rest|custom` |
| description | text | |
| days_of_week | smallint | bitmask Mon=1 … Sun=64, `CHECK (0..127)` |
| start_time | time null | |
| finish_by | time null | hard stop used by Running Late |
| status | varchar | `active|paused|archived` |
| color | varchar null | accent key from the design system |
| archived_at | timestamptz null | |
Index: `(user_id, status)`.

**routines_routineactivity**
| column | type | notes |
|---|---|---|
| routine_id | FK CASCADE | user is implied via the routine; also denormalised `user_id` for isolation checks |
| position | int | `UNIQUE (routine_id, position) DEFERRABLE INITIALLY DEFERRED` so reorder can run in one transaction |
| title, description, icon | | icon = Material Symbol name |
| target_kind | varchar | `duration|count|check` |
| target_value | numeric(10,2) | minutes for duration; 1 for check |
| minimum_value | numeric(10,2) null | `CHECK (minimum_value <= target_value)` |
| unit | varchar(32) null | "pages", "ml" |
| is_essential | bool | Minimum Day ★ |
| priority | varchar | `core|standard|optional` |
| habit_id | FK null SET NULL | |
| archived_at | timestamptz null | |

## tracking

**tracking_dailyplan**
`user_id`, `local_date` date, `mode` (`normal|minimum|recovery`), `energy` smallint null (1–5).
`UNIQUE (user_id, local_date)`.

**tracking_routineinstance**
`user_id`, `daily_plan_id` FK, `routine_id` FK null (SET NULL; the instance survives routine deletion), `routine_name` (snapshot),
`local_date`, `scheduled_start` timestamptz null, `status`, `time_budget_minutes` int null, `is_ad_hoc` bool.
`UNIQUE (routine_id, local_date) WHERE is_ad_hoc = false`. Index `(user_id, local_date)`.

**tracking_activitycompletion**
| column | type | notes |
|---|---|---|
| user_id | FK | |
| routine_instance_id | FK CASCADE | |
| activity_id | FK null SET NULL | template link |
| position, title, icon, target_kind, unit, is_essential, priority | | **snapshot** |
| target_value | numeric | original target (snapshot) |
| minimum_value | numeric null | snapshot |
| planned_value | numeric | after adaptation |
| actual_value | numeric null | |
| completion_ratio | numeric(4,3) | derived, 0–1 |
| status | varchar | `pending|in_progress|completed|partially_completed|skipped|cancelled` |
| skip_reason | varchar null | `no_time|low_energy|not_relevant|other` |
| context | jsonb | free-form (energy, location later) |
| scheduled_at, started_at, paused_at, completed_at | timestamptz null | |
| active_seconds | int default 0 | accumulated across pauses |
Indexes: `(user_id, status, completed_at)` for insights, and `(activity_id, completed_at)` for per-activity trends.
`UNIQUE (routine_instance_id, activity_id)`.

**tracking_reflection**
`user_id`, `completion_id` null, `routine_instance_id` null, `daily_plan_id` null, `note` text(500), `mood` smallint null, `energy` smallint null.
`CHECK` that at least one target is set.

**tracking_adjustment**
`user_id`, `daily_plan_id`, `routine_instance_id` null, `kind` (`running_late|time_budget|minimum_day|recovery`),
`params` jsonb, `summary` jsonb (before/after per completion), `applied_at`, `reverted_at` null.

## Idempotency

**core_idempotencykey**: `(user_id, key)` unique, `response` jsonb, `created_at`. Completion actions accept an `Idempotency-Key`
header so retries (and, later, the offline outbox) never double-apply. Rows are pruned after 7 days.

## Query notes
- `GET /days/{date}` loads the plan with `prefetch_related(instances__completions)`. That is 3 queries regardless of size.
- Materialisation runs `select_for_update` on the DailyPlan row to avoid duplicate instances from concurrent requests.
- The insights queries in M6 aggregate over `tracking_activitycompletion` by `(user_id, completed_at)`. If needed, add a nightly
  rollup table `insights_dailysummary` rather than scanning raw rows.
