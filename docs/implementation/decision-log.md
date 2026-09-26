# Decision Log

Statuses: **Proposed**, **Accepted**, **Superseded**, and **Accepted (default)**. The last one means my recommendation, applied when
implementation was approved on 2026-09-26 without a ruling on it. Those are still open to change.

| ID | Status | Decision | Rationale |
|---|---|---|---|
| D-001 | Accepted | Monorepo: `app/` (Flutter) and `backend/` (Django), with docs at the root. | A single source for API contracts and docs. |
| D-002 | Accepted (default) | Use the DESIGN.md **prose** palette (Ivory canvas, Charcoal, Ochre, Forest, Terracotta) over the M3-generated YAML/HTML palette. Radii follow the prose (cards 20–24px). | The prose matches the brief ("warm off-white"). The YAML is a cool generated scheme. See stitch-analysis §4. |
| D-003 | Accepted (default) | Forest green is the primary *action* colour. Ochre is for highlights and progress. Text on ochre is charcoal. | White on ochre fails WCAG AA (≈2.5:1). |
| D-004 | Accepted (default) | One vocabulary: Routine / Step / Start / Essential / Today's progress. Drop cadence, rhythm, ritual and flow as nouns. | Cognitive load. Stitch copy uses about 6 synonyms. |
| D-005 | Accepted | Backend apps: core, accounts, routines, tracking, goals (later insights, recommendations). | Domain boundaries, not screen boundaries (architecture.md). |
| D-006 | Accepted | ActivityCompletion rows are materialised per routine instance with snapshot fields. Template edits never rewrite history. | History is the input to insights and intelligence. |
| D-007 | Proposed | Today's progress = Σ completion ratio / items, excluding `cancelled` (system-adapted). `skipped` counts as 0 but is shown neutrally. | Minimum Day and budgets must not penalise. A user skip is honest data. |
| D-008 | Proposed | Running Late in the MVP uses the routine's `finish_by` and the scheduled start. There is no calendar or Event model until later. | Stitch assumes a "09:00 team sync" anchor the MVP can't know. |
| D-009 | Proposed | The focus card gets explicit **Mark done** and **Log partial** actions, plus a Skip sheet with optional reasons. | The design has no way to complete or partially complete, which is a core principle. |
| D-010 | Proposed | No stock or AI-generated photography in the product for now. Remove the photo cards from Today. | Licensing, stereotyping risk, and cognitive load. |
| D-011 | Accepted | JWT (15 min access / 30 day rotating refresh with blacklist), with tokens kept in secure storage. | Mobile-first and stateless. Web token storage is a known weaker point; revisit with httpOnly cookies if web becomes primary. |
| D-012 | Superseded by D-013 (codegen part) | Riverpod (codegen), go_router, dio, freezed. | Per the brief. These are standard, testable choices. |
| D-013 | Accepted | Riverpod **without** code generation (plain `Notifier`/`AsyncNotifier`). | `riverpod_generator` can't resolve against Flutter 3.41's pinned `meta`. Plain classes are equally testable and avoid generator churn. `freezed`/`json_serializable` codegen is still used. |
| D-014 | Accepted | Backend runs on Django 5.2 LTS (not 6.x). | LTS support until 2028. DRF, simplejwt and spectacular are all verified on it. |
| D-015 | Accepted | Email is stored lowercased with a plain unique constraint. Login and registration normalise case. | Django requires `unique=True` on `USERNAME_FIELD`. Normalising in `save()` gives case-insensitive uniqueness. |
| D-016 | Accepted | Auth screens (Welcome, Sign in, Create account) were built in M1 from the design system. There is no Stitch design for them. | Needed to verify the client↔API stack end to end. Visual refinement comes when designs exist. |
| D-017 | Accepted | Being offline at launch with a stored session → `SessionUnavailable` (retry on splash), not sign-out. | A daily-use app must not log people out because of a flaky connection. |
| D-018 | Accepted | The brand mark is the Stitch emblem, downloaded once and stored at `app/assets/images/mwendo_mark.png` (cropped 352x352 PNG). It's also used for the web favicon and PWA icons. | The user confirmed the Stitch "M" is the logo (2026-09-26). It ships locally and is never hotlinked. `assets/images/screen.png` was fully transparent (no visible pixels), so it wasn't usable. A vector (SVG) source is still preferable for crisp scaling and launcher icons. |
