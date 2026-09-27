import datetime as dt
import secrets

from django.conf import settings
from django.contrib.auth import password_validation
from django.contrib.auth.hashers import check_password, make_password
from django.core.mail import send_mail
from django.db import transaction
from django.utils import timezone

from apps.core.exceptions import DomainError

from .models import PasswordResetCode, Preferences, User

RESET_TTL = dt.timedelta(minutes=15)
RESET_MAX_ATTEMPTS = 5


@transaction.atomic
def register_user(*, email: str, password: str, display_name: str = "", timezone: str = "UTC") -> User:
    user = User.objects.create_user(
        email=email, password=password, display_name=display_name, timezone=timezone
    )
    Preferences.objects.create(user=user)
    return user


def request_password_reset(email: str) -> None:
    """Always behaves the same whether or not the email exists (no account enumeration)."""
    user = User.objects.filter(email__iexact=email.strip(), is_active=True).first()
    if user is None:
        return
    code = f"{secrets.randbelow(1_000_000):06d}"
    with transaction.atomic():
        PasswordResetCode.objects.filter(user=user, used_at__isnull=True).update(used_at=timezone.now())
        PasswordResetCode.objects.create(
            user=user, code_hash=make_password(code), expires_at=timezone.now() + RESET_TTL
        )
    send_mail(
        subject="Your Mwendo reset code",
        message=(
            f"Your code is {code}. It works for 15 minutes.\n\n"
            "If you didn't ask to reset your password, you can ignore this email."
        ),
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
    )


def confirm_password_reset(email: str, code: str, new_password: str) -> User:
    """Checks the code and sets the password.

    Wrong attempts are committed *before* the error is raised, so the 5-attempt lock can't be bypassed by the
    request-level transaction rolling back. The view is excluded from ATOMIC_REQUESTS for this reason.
    """
    invalid = DomainError(
        "That code isn't right or has expired. Request a new one.", code="invalid_code", status_code=400
    )
    user = User.objects.filter(email__iexact=email.strip(), is_active=True).first()
    if user is None:
        raise invalid
    password_validation.validate_password(new_password, user=user)
    with transaction.atomic():
        reset = (
            PasswordResetCode.objects.select_for_update()
            .filter(user=user, used_at__isnull=True, expires_at__gt=timezone.now())
            .order_by("-created_at")
            .first()
        )
        accepted = (
            reset is not None
            and reset.attempts < RESET_MAX_ATTEMPTS
            and check_password(code.strip(), reset.code_hash)
        )
        if reset is not None and not accepted:
            reset.attempts += 1
            reset.save(update_fields=["attempts", "updated_at"])
        if accepted:
            user.set_password(new_password)
            user.save(update_fields=["password", "updated_at"])
            reset.used_at = timezone.now()
            reset.save(update_fields=["used_at", "updated_at"])
    if not accepted:
        raise invalid
    return user
