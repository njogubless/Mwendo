from django.db import models

from apps.core.models import TimeStampedModel
from apps.routines.models import Category, RoutineActivity


class DailyPlan(TimeStampedModel):
    """The user's day: home for day-level context (mode, energy)."""

    class Mode(models.TextChoices):
        NORMAL = "normal", "Normal"
        MINIMUM = "minimum", "Minimum Day"
        RECOVERY = "recovery", "Recovery"

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="daily_plans")
    local_date = models.DateField()
    mode = models.CharField(max_length=10, choices=Mode.choices, default=Mode.NORMAL)
    energy = models.PositiveSmallIntegerField(null=True, blank=True)
    recovery_dismissed = models.BooleanField(default=False)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "local_date"], name="tracking_plan_user_date")]


class RoutineInstance(TimeStampedModel):
    """A routine as it happens on one date. Survives edits/deletion of the template."""

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    daily_plan = models.ForeignKey(DailyPlan, on_delete=models.CASCADE, related_name="instances")
    routine = models.ForeignKey(
        "routines.Routine", on_delete=models.SET_NULL, null=True, blank=True, related_name="instances"
    )
    routine_name = models.CharField(max_length=80)
    category = models.CharField(max_length=12, choices=Category.choices, default=Category.OTHER)
    local_date = models.DateField()
    scheduled_start = models.DateTimeField(null=True, blank=True)
    finish_by = models.DateTimeField(null=True, blank=True)
    is_ad_hoc = models.BooleanField(default=False)

    class Meta:
        ordering = ["scheduled_start", "created_at"]
        indexes = [models.Index(fields=["user", "local_date"])]
        constraints = [
            models.UniqueConstraint(
                fields=["routine", "local_date"],
                condition=models.Q(is_ad_hoc=False),
                name="tracking_instance_routine_date",
            )
        ]


class ActivityCompletion(TimeStampedModel):
    """One step's occurrence on a day and what actually happened.

    Snapshot fields are copied from the template at materialisation, so later edits never rewrite history.
    `target_value` is the original target, `planned_value` the target after adaptation and
    `actual_value` what really happened.
    """

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        IN_PROGRESS = "in_progress", "In progress"
        COMPLETED = "completed", "Completed"
        PARTIAL = "partially_completed", "Partially completed"
        SKIPPED = "skipped", "Skipped"  # the user chose not to
        CANCELLED = (
            "cancelled",
            "Set aside",
        )  # removed by an approved adaptation; never counted against the user

    class SkipReason(models.TextChoices):
        NO_TIME = "no_time", "Not enough time"
        LOW_ENERGY = "low_energy", "Low energy"
        NOT_RELEVANT = "not_relevant", "Not relevant today"
        OTHER = "other", "Something else"

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    routine_instance = models.ForeignKey(
        RoutineInstance, on_delete=models.CASCADE, related_name="completions"
    )
    activity = models.ForeignKey(
        "routines.RoutineActivity",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="completions",
    )
    # Snapshot
    position = models.PositiveIntegerField(default=0)
    title = models.CharField(max_length=80)
    description = models.CharField(max_length=200, blank=True)
    icon = models.CharField(max_length=40, default="check_circle")
    target_kind = models.CharField(max_length=10, choices=RoutineActivity.TargetKind.choices)
    unit = models.CharField(max_length=24, blank=True)
    is_essential = models.BooleanField(default=False)
    priority = models.CharField(max_length=10, choices=RoutineActivity.Priority.choices)
    target_value = models.DecimalField(max_digits=8, decimal_places=2)
    minimum_value = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    # Outcome
    planned_value = models.DecimalField(max_digits=8, decimal_places=2)
    actual_value = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    completion_ratio = models.DecimalField(max_digits=4, decimal_places=3, default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    skip_reason = models.CharField(max_length=16, choices=SkipReason.choices, blank=True)
    context = models.JSONField(default=dict, blank=True)
    # Timing
    scheduled_at = models.DateTimeField(null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    running_since = models.DateTimeField(null=True, blank=True)  # null while paused
    completed_at = models.DateTimeField(null=True, blank=True)
    active_seconds = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["scheduled_at", "position"]
        indexes = [
            models.Index(fields=["user", "status", "completed_at"]),
            models.Index(fields=["activity", "completed_at"]),
        ]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(completion_ratio__gte=0) & models.Q(completion_ratio__lte=1),
                name="tracking_completion_ratio_range",
            )
        ]

    @property
    def is_running(self) -> bool:
        return self.status == self.Status.IN_PROGRESS and self.running_since is not None


class Reflection(TimeStampedModel):
    """Optional context about how something went."""

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    completion = models.ForeignKey(
        ActivityCompletion, on_delete=models.CASCADE, null=True, blank=True, related_name="reflections"
    )
    daily_plan = models.ForeignKey(
        DailyPlan, on_delete=models.CASCADE, null=True, blank=True, related_name="reflections"
    )
    note = models.CharField(max_length=500, blank=True)
    mood = models.PositiveSmallIntegerField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.CheckConstraint(
                condition=models.Q(completion__isnull=False) | models.Q(daily_plan__isnull=False),
                name="tracking_reflection_has_target",
            )
        ]


class Adjustment(TimeStampedModel):
    """An approved adaptation. Stores before/after per completion so it is transparent and revertible."""

    class Kind(models.TextChoices):
        TIME_BUDGET = "time_budget", "Time budget"
        MINIMUM_DAY = "minimum_day", "Minimum Day"
        RECOVERY = "recovery", "Recovery"

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    daily_plan = models.ForeignKey(DailyPlan, on_delete=models.CASCADE, related_name="adjustments")
    routine_instance = models.ForeignKey(
        RoutineInstance, on_delete=models.CASCADE, null=True, blank=True, related_name="adjustments"
    )
    kind = models.CharField(max_length=12, choices=Kind.choices)
    params = models.JSONField(default=dict)
    # [{"completion": id, "before": {"planned_value", "status"}, "after": {...}}]
    changes = models.JSONField(default=list)
    reverted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
