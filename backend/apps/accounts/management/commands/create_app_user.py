"""Create an app account from the backend (dev/support), the same way registration does.

    python manage.py create_app_user --email amani@example.com --password steady-river-42 \
        --name Amani --timezone Africa/Nairobi [--onboarded]
"""

from django.contrib.auth import password_validation
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone as dj_timezone

from apps.accounts.models import User
from apps.accounts.services import register_user
from apps.accounts.validators import validate_timezone


class Command(BaseCommand):
    help = "Create a Mwendo app user (email + password) that can sign in from the app."

    def add_arguments(self, parser):
        parser.add_argument("--email", required=True)
        parser.add_argument("--password", required=True)
        parser.add_argument("--name", default="")
        parser.add_argument("--timezone", default="Africa/Nairobi")
        parser.add_argument(
            "--onboarded", action="store_true", help="Skip onboarding and go straight to Today after sign-in."
        )

    def handle(self, *args, email, password, name, timezone: str, onboarded, **options):
        email = email.strip().lower()
        if User.objects.filter(email__iexact=email).exists():
            raise CommandError(f"An account with {email} already exists.")
        try:
            validate_timezone(timezone)
            password_validation.validate_password(password, user=User(email=email, display_name=name))
        except ValidationError as exc:
            raise CommandError(" ".join(exc.messages)) from exc
        user = register_user(email=email, password=password, display_name=name, timezone=timezone)
        if onboarded:
            user.onboarding_completed_at = dj_timezone.now()
            user.save(update_fields=["onboarding_completed_at", "updated_at"])
        self.stdout.write(
            self.style.SUCCESS(f"Created {email} ({timezone}). Sign in from the app with this email.")
        )
