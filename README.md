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
.venv/bin/python manage.py runserver 0.0.0.0:8001   # reachable from phones on your Wi-Fi (dev only)

# 3. App
cd app
flutter pub get
flutter run                  # web, emulator or phone — no flags
```

### Which server does the app use?
One place decides (`app/lib/core/config/env.dart`):

| Build | Server |
|---|---|
| `--dart-define=API_BASE_URL=…` given | That URL, always (CI, staging, production builds) |
| Release (`flutter build … --release`) | `Env.productionApiUrl`, the deployed API |
| Debug (`flutter run`) | The server picked in the app's **developer Server screen**, remembered on the device. Default is `localhost:8001` | subject to change depending on client server being rendered

On a **phone**, tap **Server: …** at the bottom of the Welcome screen once, then choose:
- **Wi-Fi:** type your computer's address, e.g. `192.168.31.222:8001` (`hostname -I`), tap **Test**, then **Use this server**.
- **USB:** keep *This computer* and run `./tool/run_dev.sh` (it sets up `adb reverse`).

After that, plain `flutter run` keeps using that server. Release builds ignore this screen and always use production.

### Reminders (phone only)
Turn them on from the card on Today or in Profile › Reminders. On Android, allow **Alarms & reminders**
when asked, so they arrive on the minute; otherwise Android may deliver a few minutes late. Reminders
are planned on the phone from today's plan and your routines, and update whenever those change.

- Design-system gallery (debug builds): the app's welcome screen links to `/dev/gallery`

See `docs/` for the product, design, architecture and plan.
