import datetime
import uuid

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.utils import timezone as dj_timezone

from apps.core.models import TimeStampedModel

from .validators import validate_timezone


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create(self, email, password, **extra):
        if not email:
            raise ValueError("Email is required")
        user = self.model(email=self.normalize_email(email).lower(), **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra):
        extra.setdefault("is_staff", False)
        extra.setdefault("is_superuser", False)
        return self._create(email, password, **extra)

    def create_superuser(self, email, password=None, **extra):
        extra.update(is_staff=True, is_superuser=True)
        return self._create(email, password, **extra)

    def get_by_natural_key(self, email):
        return self.get(email__iexact=email)


class User(AbstractBaseUser, PermissionsMixin):
    """Email-login user. `timezone` + `day_start_time` define what "today" means for this person."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(max_length=254, unique=True)  # always stored lowercased
    display_name = models.CharField(max_length=80, blank=True)
    timezone = models.CharField(max_length=64, default="UTC", validators=[validate_timezone])
    day_start_time = models.TimeField(default=datetime.time(4, 0))
    onboarding_completed_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=dj_timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    EMAIL_FIELD = "email"
    REQUIRED_FIELDS: list[str] = []

    def save(self, *args, **kwargs):
        self.email = (self.email or "").strip().lower()
        super().save(*args, **kwargs)

    def __str__(self):
        return self.email

    @property
    def is_onboarded(self) -> bool:
        return self.onboarding_completed_at is not None


class Preferences(TimeStampedModel):
    """Onboarding answers and routine-shaping preferences."""

    class Structure(models.TextChoices):
        LOOSE = "loose", "Loose"
        BALANCED = "balanced", "Balanced"
        STRUCTURED = "structured", "Structured"

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="preferences")
    structure = models.CharField(max_length=16, choices=Structure.choices, default=Structure.BALANCED)
    wake_time = models.TimeField(null=True, blank=True)
    focus_areas = ArrayField(models.CharField(max_length=32), default=list, blank=True)
    ideal_day = models.JSONField(default=dict, blank=True)

    class Meta:
        verbose_name_plural = "preferences"
