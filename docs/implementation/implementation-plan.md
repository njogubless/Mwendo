# Implementation Plan

Status: **M1 Foundation complete (2026-09-26). Waiting for confirmation before M2.**

Each milestone ends with: backend tests green, `flutter analyze` clean, Flutter tests green, docs updated, and a demoable flow.

## M0: Decisions and design gaps (now)
- Review the design decisions in [decision-log.md](decision-log.md) (D-001 to D-010), especially the token reconciliation, vocabulary, and completion UX.
- Agree on designs, or accept low-fidelity implementations that follow the design system, for the screens with no design (auth, onboarding, sheets, goals).
- `git init`, with `.gitignore` and `.editorconfig`.

## M1: Foundation ✅
**Backend**
- Scaffold `backend/` with split settings (`base`, `dev`, `test`, `prod`), django-environ, `.env.example`, and docker-compose Postgres.
- `core`: UUID/timestamp base model, error envelope handler, request-ID middleware, pagination, `IsOwner` / owner-scoped base viewset, health endpoint.
- `accounts`: **custom User model before the first migration** (email login, timezone, day_start_time), Preferences, and admin.
- JWT auth (register, login, refresh, logout with blacklist), throttling, and drf-spectacular at `/api/v1/schema/`.
- pytest config, factories, and tests for the auth flow and the error envelope.

**Flutter**
- `flutter create app` (iOS, Android, web). Add lints (`very_good_analysis` or strict `flutter_lints` + custom).
- Theme: tokens as `ThemeExtension`s (light and dark), bundled Plus Jakarta Sans, and `design-system.md` written from the reconciled tokens.
- Core widgets: `MwCard`, buttons, `StatusPill`, `ProgressRing`, `SegmentedStrand`, `MwToggle`, `SectionLabel`, and
  Loading/Empty/Error/Offline views. A widget gallery route (dev only) for visual review.
- go_router with an adaptive shell (dock / rail / sidebar) and placeholder tabs. Dio client, `AppFailure` mapping, and a secure token store.
- Test infrastructure: provider overrides, golden tests for core widgets.

*Delivered:* everything above, plus Welcome / Sign in / Create account screens wired to the API (D-016). Verified end to end
against a live server and Postgres, and screenshotted on web. 26 backend and 46 Flutter tests, analyzer and ruff clean.
*Not done:* golden tests (deferred, see testing.md) and CI (no remote yet).

**Done when:** `docker compose up db && pytest` passes, the app runs on Android and web showing the themed shell and widget gallery, and the OpenAPI schema is served.

## M2: Auth and onboarding
- Carried over: an onboarding redirect guard (signed in but not onboarded → `/onboarding`).
- Backend: password reset (token plus email backend, console in dev), `/me`, preferences, `POST /routines/generate/`
  (a deterministic template generator driven by focus areas, structure and wake time), and onboarding completion.
- Flutter: Forgot/reset password and the 5 onboarding steps (Splash, Welcome and Sign in/Register already exist), then review of the generated routine, then Today.
- Router guards: unauthenticated → auth, and not onboarded → onboarding.
- Tests: register/login/refresh/logout, reset flow, generator unit tests, onboarding widget tests, integration test for register → onboarding → Today.

## M3: Today (the core loop)
- Backend `tracking`: DailyPlan, RoutineInstance, ActivityCompletion, and Reflection. Idempotent materialisation, focus selection,
  start/pause/complete/partial/skip/reset services, progress computation, and idempotency keys.
- Flutter: Today screen matching S-TODAY (minus deferred adaptive pieces), `FocusActivityCard`, timeline, complete/partial/skip/reflection
  sheets, optimistic updates, and empty states (rest day, all done).
- Tests: materialisation under time zones and day_start_time boundaries, status transitions, progress math, user isolation,
  notifier tests, widget tests for each timeline state, and an integration test for complete / partial / skip.

## M4: Routines and goals
- Routines list and filter, routine editor, activity editor, reorder, essential ★, pause/archive, and ad-hoc start. Template edits re-sync today's pending items.
- Goals and habits CRUD, linking activities to habits, and goal progress (derived and manual measurements).
- Tests: reorder transaction, snapshot immutability, goal progress aggregation.

## M5: Adaptation (deterministic)
- A pure planner: `plan_adaptation(items, budget | late_by | mode) → proposal`, with preview/apply/revert and Adjustment records.
- Minimum Day, Running Late, Time Budget, priority handling, and Recovery Mode (triggered after N days of inactivity, and offers a lighter plan).
- S-ADAPT screen and the Today entry points.
- Tests: extensive planner unit tests (property-style: never below minimum, essentials kept first, total ≤ budget).

## M6: Insights
Consistency, weekly summary, trends, and simple patterns (time-of-day completion rates), plus the Insights screen and the Routines summary card.

## M7: Intelligence
Recommendations and experiments built on M6 patterns, with explicit accept/dismiss. LLM features only after this, and only behind the same approval flow.

## Cross-cutting and post-MVP
Offline outbox (drift), push notifications, calendar anchors (Event), accessibility audit, localisation (en, sw), and analytics.
