# Architecture

## Repository layout (monorepo)

```
mwendo/
├── app/                 Flutter client (iOS, Android, web; desktop later)
├── backend/             Django + DRF API
├── docs/                Product, design, architecture, engineering, implementation
├── stitch/              Stitch exports (read-only visual reference)
├── docker-compose.yml   Local Postgres (and later Redis/mail catcher)
└── CLAUDE.md            Working agreement for AI-assisted development
```

---

## Backend

**Stack:** Python 3.12, Django 5.2 LTS, DRF, PostgreSQL 16, psycopg 3, `djangorestframework-simplejwt` (rotation + blacklist),
`drf-spectacular` (OpenAPI 3), `django-environ`, `django-filter`, `argon2-cffi`. Tests use pytest, pytest-django and factory_boy.

### Apps
Each app corresponds to a real business responsibility. Nothing is split for its own sake.

| App | Owns | Milestone |
|---|---|---|
| `core` | base models (UUID and timestamps), error handler, pagination, permissions (`IsOwner`), idempotency, health | M1 |
| `accounts` | User, Preferences, auth, password reset, onboarding status | M1–M2 |
| `routines` | Routine, RoutineActivity, schedule rules, routine generation from onboarding answers | M2–M4 |
| `tracking` | DailyPlan, RoutineInstance, ActivityCompletion, Reflection, Adjustment. Materialisation, completion and **adaptation engine** | M3, M5 |
| `goals` | Goal, Habit, Measurement, progress computation | M4 |
| `insights` | read-only aggregations, patterns | M6 |
| `recommendations` | Recommendation, Experiment | M7 |

The prompt's separate `habits`, `activities` and `completions` apps are folded in: habits live with goals (they exist to serve them), activities
live with routines (they are routine templates), and completions live in `tracking` (they share the day and instance lifecycle and transactions).

### Layers inside an app
```
apps/<app>/
├── models.py        Persistence plus simple invariants (constraints, clean)
├── services/        Business operations: transactions, multi-model changes (e.g. complete_activity, materialise_day)
├── domain/          Pure functions with no ORM (e.g. adaptation planner, progress math). Heavily unit-tested
├── selectors.py     Read queries with prefetching (no business side effects)
├── serializers.py   Validation and representation only
├── views.py         Thin: auth → serializer → service/selector → response
├── urls.py
└── tests/
```
Rule: views never contain business logic, and serializers never write to more than one model.

### API conventions
- Base path `/api/v1/`. The version is in the URL.
- Resources, not screens. The one aggregate read is `GET /api/v1/days/{date}/`. It is a real domain resource
  (the user's DailyPlan with nested instances and completions), not a "build screen" endpoint.
- State transitions use explicit action endpoints (`POST /completions/{id}/complete/`) rather than a free-form `PATCH status`.
  This keeps invariants on the server.
- Errors use one envelope:
  `{"error": {"code": "validation_error", "message": "…", "details": {field: [..]}, "request_id": "…"}}`
- Cursor pagination on history lists and page-number pagination on small collections. `django-filter` handles querystrings.
- OpenAPI lives at `/api/v1/schema/`, with Swagger UI at `/api/v1/docs/` (dev only). The Flutter DTOs are checked against it.
- `Idempotency-Key` header on completion and adaptation actions.

### Initial endpoint map
```
POST   /auth/register/            POST /auth/login/          POST /auth/refresh/
POST   /auth/logout/              POST /auth/password/reset/ POST /auth/password/reset/confirm/
GET/PATCH /me/                    GET/PUT /me/preferences/   POST /me/onboarding/complete/

GET/POST /routines/               GET/PATCH/DELETE /routines/{id}/     (DELETE = archive)
POST   /routines/generate/        (onboarding answers → unsaved draft; client reviews then POSTs /routines/)
GET/POST /routines/{id}/activities/   PATCH/DELETE /routines/{id}/activities/{aid}/
POST   /routines/{id}/activities/reorder/
POST   /routines/{id}/start/      (ad-hoc instance for today)

GET    /days/{date}/              (lazy, idempotent materialisation)   PATCH /days/{date}/  (mode, energy)
POST   /completions/{id}/start/ | pause/ | complete/ | skip/ | reset/
POST   /routine-instances/{id}/adaptation/preview/   POST …/adaptation/apply/   POST /adjustments/{id}/revert/
GET/POST /reflections/

GET/POST /goals/   GET/PATCH/DELETE /goals/{id}/   GET /goals/{id}/progress/
GET/POST /habits/  …
```

### Security
- JWT: 15-minute access token and 30-day rotating refresh token, with blacklisting on logout and rotation.
- Argon2 password hashing and Django password validators.
- DRF throttling: `auth` scope (e.g. 10/min per IP on login, register and reset) and a default user rate.
- Every queryset is filtered by `request.user` in a shared base viewset, and there are tests asserting 404 (not 403) on other users' IDs.
- Password reset responses are identical whether or not the email exists.
- Secrets come from the environment only (`.env` for local, git-ignored, with `.env.example` committed). `DEBUG` is false by default.
  Production settings enforce HTTPS and HSTS, secure cookies, and a strict `ALLOWED_HOSTS` and CORS.
- A Sentry-ready logging config with a request ID middleware. No PII in logs.

---

## Flutter client

**Stack:** Flutter 3.41 / Dart 3.11, `flutter_riverpod` (+ `riverpod_annotation` codegen), `go_router`, `dio`,
`freezed` + `json_serializable`, `flutter_secure_storage`, `material_symbols_icons`, and a bundled Plus Jakarta Sans.
Tests use `flutter_test`, `mocktail` and `integration_test`. Later: `drift` for local persistence.

### Structure
```
app/lib/
├── main.dart / app.dart             ProviderScope, MaterialApp.router
├── core/
│   ├── config/        env (dart-define), flavors
│   ├── network/       Dio client, auth interceptor (refresh w/ single-flight), error mapping, idempotency keys
│   ├── errors/        AppFailure sealed class (network, unauthorized, validation, server, offline, unknown)
│   ├── routing/       go_router config, auth/onboarding redirect guards, adaptive shell (dock / rail / sidebar)
│   ├── storage/       secure token store
│   ├── theme/         MwColors/MwTypography/MwSpacing/MwRadii/MwShadows as ThemeExtensions; light + dark
│   ├── widgets/       design-system components (MwCard, ProgressRing, SegmentedStrand, StatusPill, MwBottomDock …)
│   └── utils/
└── features/<feature>/
    ├── domain/        entities (freezed), value objects, repository interfaces, pure logic (e.g. progress)
    ├── data/          DTOs, remote data source, repository implementation (DTO → entity mapping)
    ├── application/   Riverpod Notifiers/AsyncNotifiers (use-case orchestration, state)
    └── presentation/  screens + feature-specific widgets (no business logic)
```
Features: `auth`, `onboarding`, `today`, `routines`, `goals`, `insights`, `profile`. `recovery` and `adaptation` live under
`today` until they grow large enough to split.

### Rules
- Widgets read state from providers and call notifier methods. They never touch Dio or DTOs.
- Repositories return domain entities, or throw/return a typed `AppFailure`. Screens render `AsyncValue` with shared
  `LoadingView` / `EmptyView` / `ErrorView` / `OfflineBanner`.
- Mutations on Today are **optimistic**: update local state, send the action with an idempotency key, and reconcile or roll back with a calm message.
- Dependency injection happens via providers. Tests override repository providers with fakes.

### Offline-readiness (not full offline in MVP)
- Repository interfaces are the seam. M3 adds an in-memory cache of the current day. Post-MVP swaps in a `drift` local
  datasource and an **outbox** of completion actions keyed by idempotency key. The server already supports safe replays.
- Completion actions carry a client timestamp (`occurred_at`), so queued actions record when they really happened.

### Responsive
Breakpoints: compact < 600, medium 600–1024, expanded > 1024 (content max 1200). The shell switches between the bottom dock, a
NavigationRail and a sidebar. Today goes two-column on medium and up (progress and focus | sequence).

---

## Environments and tooling
- Local: `docker compose up db`, then `backend/.venv`, and `flutter run --dart-define=API_BASE_URL=…`.
- CI (after git is initialised): ruff, pytest with coverage, `manage.py makemigrations --check`, spectacular schema diff, `flutter analyze`, `flutter test`.
