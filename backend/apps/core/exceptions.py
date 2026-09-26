"""One error envelope for every API failure:

    {"error": {"code": "...", "message": "...", "details": {...}, "request_id": "..."}}

`code` is stable and machine-readable; `message` is safe to show to users.
"""

import logging

from django.core.exceptions import PermissionDenied
from django.http import Http404
from rest_framework import exceptions, status
from rest_framework.response import Response
from rest_framework.views import exception_handler

from .middleware import get_request_id

logger = logging.getLogger(__name__)

_MESSAGES = {
    "token_not_valid": "Your session has ended. Please sign in again.",
    "validation_error": "Some details need another look.",
    "not_authenticated": "Please sign in to continue.",
    "authentication_failed": "Your session has ended. Please sign in again.",
    "permission_denied": "You don't have access to this.",
    "not_found": "We couldn't find that.",
    "method_not_allowed": "That action isn't supported here.",
    "throttled": "Too many attempts. Please wait a moment and try again.",
    "server_error": "Something went wrong on our side. Please try again.",
}


class DomainError(exceptions.APIException):
    """Raise from services for business-rule violations (e.g. completing a cancelled activity)."""

    status_code = status.HTTP_409_CONFLICT
    default_code = "conflict"
    default_detail = "That change can't be made right now."

    def __init__(self, message=None, code=None, status_code=None):
        super().__init__(detail=message or self.default_detail, code=code or self.default_code)
        if status_code:
            self.status_code = status_code


def _error(code, message, http_status, details=None):
    body = {
        "error": {"code": code, "message": message, "details": details or {}, "request_id": get_request_id()}
    }
    return Response(body, status=http_status)


def _code_of(exc) -> str:
    """Stable string code; some libraries (simplejwt) nest it inside a dict detail."""
    codes = exc.get_codes() if isinstance(exc, exceptions.APIException) else "error"
    if isinstance(codes, dict):
        codes = codes.get("code", "error")
    if isinstance(codes, list):
        codes = codes[0] if codes else "error"
    return codes if isinstance(codes, str) else "error"


def api_exception_handler(exc, context):
    if isinstance(exc, Http404):
        exc = exceptions.NotFound()
    elif isinstance(exc, PermissionDenied):
        exc = exceptions.PermissionDenied()

    response = exception_handler(exc, context)
    if response is None:
        logger.exception("Unhandled API error", exc_info=exc)
        return _error("server_error", _MESSAGES["server_error"], status.HTTP_500_INTERNAL_SERVER_ERROR)

    if isinstance(exc, exceptions.ValidationError):
        details = exc.detail if isinstance(exc.detail, dict) else {"non_field_errors": exc.detail}
        return _error("validation_error", _MESSAGES["validation_error"], response.status_code, details)

    if isinstance(exc, DomainError):
        return _error(exc.get_codes(), str(exc.detail), response.status_code)

    code = _code_of(exc)
    detail = getattr(exc, "detail", None)
    fallback = detail if isinstance(detail, str) and detail else _MESSAGES["server_error"]
    message = _MESSAGES.get(code, fallback)
    error_response = _error(code, message, response.status_code)
    for header in ("Retry-After", "WWW-Authenticate", "Allow"):
        if header in response:
            error_response[header] = response[header]
    return error_response
