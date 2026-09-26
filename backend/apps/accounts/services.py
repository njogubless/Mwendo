from django.db import transaction

from .models import Preferences, User


@transaction.atomic
def register_user(*, email: str, password: str, display_name: str = "", timezone: str = "UTC") -> User:
    user = User.objects.create_user(
        email=email, password=password, display_name=display_name, timezone=timezone
    )
    Preferences.objects.create(user=user)
    return user
