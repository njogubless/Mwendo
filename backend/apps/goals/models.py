from django.db import models

from apps.core.models import TimeStampedModel


class Goal(TimeStampedModel):
    """Something the user is moving toward.

    Progress is derived (measurements + supporting habits), never stored.
    """

    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        PAUSED = "paused", "Paused"
        ACHIEVED = "achieved", "Achieved"
        ARCHIVED = "archived", "Archived"

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="goals")
    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    area = models.CharField(max_length=32, blank=True)
    target_value = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    unit = models.CharField(max_length=32, blank=True)
    target_date = models.DateField(null=True, blank=True)
    status = models.CharField(max_length=12, choices=Status.choices, default=Status.ACTIVE)
    achieved_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["status", "-created_at"]
        indexes = [models.Index(fields=["user", "status"])]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(target_value__isnull=True) | models.Q(target_value__gt=0),
                name="goals_goal_target_positive",
            )
        ]

    def __str__(self):
        return self.title


class Habit(TimeStampedModel):
    """A repeated behaviour that supports a goal. Performed through routine steps linked to it."""

    class Per(models.TextChoices):
        DAY = "day", "Day"
        WEEK = "week", "Week"

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="habits")
    goal = models.ForeignKey(Goal, on_delete=models.SET_NULL, null=True, blank=True, related_name="habits")
    title = models.CharField(max_length=120)
    frequency_per = models.CharField(max_length=4, choices=Per.choices, default=Per.DAY)
    frequency_times = models.PositiveSmallIntegerField(default=1)
    archived_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["created_at"]
        indexes = [models.Index(fields=["user", "goal"])]

    def __str__(self):
        return self.title


class Measurement(TimeStampedModel):
    """A manual progress entry toward a goal ("finished book 4" → +1)."""

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    goal = models.ForeignKey(Goal, on_delete=models.CASCADE, related_name="measurements")
    value = models.DecimalField(max_digits=10, decimal_places=2)
    recorded_on = models.DateField()
    note = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ["-recorded_on", "-created_at"]
