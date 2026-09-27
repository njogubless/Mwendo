from django.contrib.postgres.fields import ArrayField
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.core.models import TimeStampedModel


class Category(models.TextChoices):
    MORNING = "morning", "Morning"
    WORK = "work", "Focus"
    EVENING = "evening", "Evening"
    REST = "rest", "Rest"
    OTHER = "other", "Other"


class Routine(TimeStampedModel):
    """A template: ordered steps with a weekly schedule. Days are materialised from it (tracking app)."""

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"  # scheduled
        PAUSED = "paused", "Paused"  # kept, not scheduled
        ARCHIVED = "archived", "Archived"  # hidden, history retained

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="routines")
    name = models.CharField(max_length=80)
    category = models.CharField(max_length=12, choices=Category.choices, default=Category.OTHER)
    description = models.CharField(max_length=240, blank=True)
    # ISO weekdays, Monday=1 … Sunday=7.
    days_of_week = ArrayField(
        models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(7)]),
        default=list,
        blank=True,
    )
    start_time = models.TimeField(null=True, blank=True)
    # Optional hard stop the Running Late adaptation protects ("be done by 09:00").
    finish_by = models.TimeField(null=True, blank=True)
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.ACTIVE)
    archived_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["start_time", "name"]
        indexes = [models.Index(fields=["user", "status"])]

    def __str__(self):
        return self.name

    def is_scheduled_on(self, weekday: int) -> bool:
        return self.status == self.Status.ACTIVE and weekday in (self.days_of_week or [])


class RoutineActivity(TimeStampedModel):
    """One step of a routine template (UI: "Step")."""

    class TargetKind(models.TextChoices):
        DURATION = "duration", "Duration (minutes)"
        COUNT = "count", "Count"
        CHECK = "check", "Just do it"

    class Priority(models.TextChoices):
        CORE = "core", "Core"
        STANDARD = "standard", "Standard"
        OPTIONAL = "optional", "Optional"

    routine = models.ForeignKey(Routine, on_delete=models.CASCADE, related_name="activities")
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    position = models.PositiveIntegerField(default=0)
    title = models.CharField(max_length=80)
    description = models.CharField(max_length=200, blank=True)
    icon = models.CharField(max_length=40, default="check_circle")
    target_kind = models.CharField(max_length=10, choices=TargetKind.choices, default=TargetKind.DURATION)
    target_value = models.DecimalField(max_digits=8, decimal_places=2, default=10)
    # Smallest version that still counts. Compression never goes below it.
    minimum_value = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    unit = models.CharField(max_length=24, blank=True)
    is_essential = models.BooleanField(default=False)
    priority = models.CharField(max_length=10, choices=Priority.choices, default=Priority.STANDARD)
    habit = models.ForeignKey(
        "goals.Habit", on_delete=models.SET_NULL, null=True, blank=True, related_name="activities"
    )
    archived_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["position", "created_at"]
        verbose_name_plural = "routine activities"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(target_value__gt=0), name="routines_activity_target_positive"
            ),
            models.CheckConstraint(
                condition=models.Q(minimum_value__isnull=True)
                | (models.Q(minimum_value__gt=0) & models.Q(minimum_value__lte=models.F("target_value"))),
                name="routines_activity_minimum_within_target",
            ),
        ]

    def __str__(self):
        return self.title
