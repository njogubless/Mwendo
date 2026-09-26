# Testing

## Backend (`backend/`)
```bash
docker compose up -d db                    # Postgres 16 on localhost:5433
.venv/bin/pytest                           # uses config.settings.test, --reuse-db
.venv/bin/pytest --create-db --cov         # after model changes / for coverage
.venv/bin/ruff check . && .venv/bin/ruff format --check .
.venv/bin/python manage.py makemigrations --check --dry-run
.venv/bin/python manage.py spectacular --validate --fail-on-warn --file /tmp/schema.yml
```
- Tests run against real PostgreSQL, not SQLite, because we rely on Postgres features (ArrayField, and later partial unique constraints).
- Use factories (`apps/*/tests/factories.py`) and never fixtures in JSON.
- Every endpoint needs tests for success, validation, unauthenticated access, and **another user's object (expect 404)**.
- Test files live at `apps/<app>/tests/test_*.py`. Name tests after the behaviour, not the method.

## Flutter (`app/`)
```bash
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs   # after changing freezed/json models
```
- **Unit tests:** pure logic (redirect guard, failure mapping, domain calculations).
- **Repository and network tests:** `test/helpers/fake_http.dart` scripts HTTP responses through a fake `HttpClientAdapter`,
  so no network is involved.
- **Controller tests:** use a `ProviderContainer` with repository providers overridden by `mocktail` mocks.
- **Widget tests:** `test/helpers/pump_app.dart` wraps the widget in the theme. Assert behaviour and semantics, not pixels.
- **Layout safety:** `gallery_test.dart` renders every component at 320/390/800/1280px in light and dark and fails on overflow.
- **Golden tests** are deferred. Font rasterisation differs across machines, so we'll add them with a pinned CI image.

## Current coverage (M1)
Backend: 26 tests covering auth (register, login, refresh rotation, logout and blacklist, cross-user logout), `/me`, preferences,
onboarding completion, the error envelope, request IDs, health and the schema.
Flutter: 46 tests covering failure mapping, the auth interceptor (refresh, single-flight, expiry), redirects, the session controller,
the auth repository, components, the adaptive shell at 3 widths, gallery overflow, and the auth form.
