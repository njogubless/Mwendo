# Error Handling

## Backend
All API errors go through `apps/core/exceptions.py::api_exception_handler` and use one envelope:

```json
{"error": {"code": "validation_error", "message": "Some details need another look.",
           "details": {"email": ["An account with this email already exists."]}, "request_id": "…"}}
```

- `code` is stable and machine-readable. Clients branch on it and never on `message`.
- `message` is calm and safe to show. Internal details (exception text, library structures) never leak. Unhandled
  exceptions are logged with their traceback and return a generic `server_error` 500.
- `details` holds field errors, but only for validation. Field-level errors must be attached to the field (e.g. password
  strength goes under `password`, not `non_field_errors`) so the client can show them inline.
- Business-rule violations raise `DomainError(message, code=…)`, which returns 409 by default.
- Every response carries `X-Request-ID`. The client may send its own, and it's also included in log lines.

## Flutter
- The transport layer converts everything into a sealed `AppFailure` (`core/errors/app_failure.dart`) via
  `core/network/failure_mapper.dart`. Widgets never see Dio types.
- Repositories throw `AppFailure`. Controllers either expose it through `AsyncValue` or rethrow it to forms.
- Screens use the shared `LoadingView`, `EmptyView`, `ErrorView` (with retry) and `OfflineBanner`.
- A 401 triggers one single-flight refresh (`AuthInterceptor`). If the refresh fails, tokens are cleared and
  `SessionEvents.expired` fires. The session controller then signs out and gives a gentle reason.
- Being offline at launch with a stored session puts the app in `SessionUnavailable` (retry on splash), **not** signed out.
- Sign-out always clears local credentials, even when the network call fails.
