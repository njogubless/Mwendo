# Mwendo

*Find your rhythm. Move forward.*

Mwendo is an adaptive daily routine and personal progress app, built with Flutter, Django REST Framework and PostgreSQL.

## Quick start

```bash
# 1. Database
docker compose up -d db

# 2. API
cd backend
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
cp .env.example .env            # then set DJANGO_SECRET_KEY
.venv/bin/python manage.py migrate
.venv/bin/python manage.py runserver 8001

# 3. App
cd app
flutter pub get
flutter run -d chrome
```

- API docs: http://localhost:8001/api/v1/docs/
- Design-system gallery (debug builds): the app's welcome screen links to `/dev/gallery`

See `CLAUDE.md` for conventions and `docs/` for the product, design, architecture and plan.
