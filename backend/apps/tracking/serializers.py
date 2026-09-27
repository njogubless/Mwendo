from rest_framework import serializers

from apps.routines.models import Category, RoutineActivity

from .models import ActivityCompletion, Adjustment, DailyPlan

D = {"max_digits": 8, "decimal_places": 2}


class CompletionSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    routine_instance_id = serializers.UUIDField()
    activity_id = serializers.UUIDField(allow_null=True)
    title = serializers.CharField()
    description = serializers.CharField()
    icon = serializers.CharField()
    target_kind = serializers.ChoiceField(RoutineActivity.TargetKind.choices)
    unit = serializers.CharField()
    is_essential = serializers.BooleanField()
    priority = serializers.ChoiceField(RoutineActivity.Priority.choices)
    target_value = serializers.DecimalField(**D)
    minimum_value = serializers.DecimalField(**D, allow_null=True)
    planned_value = serializers.DecimalField(**D)
    actual_value = serializers.DecimalField(**D, allow_null=True)
    completion_ratio = serializers.DecimalField(max_digits=4, decimal_places=3)
    status = serializers.ChoiceField(ActivityCompletion.Status.choices)
    skip_reason = serializers.CharField()
    scheduled_at = serializers.DateTimeField(allow_null=True)
    started_at = serializers.DateTimeField(allow_null=True)
    completed_at = serializers.DateTimeField(allow_null=True)
    elapsed_seconds = serializers.IntegerField()
    is_running = serializers.BooleanField()
    reflection = serializers.CharField()


class AdjustmentRefSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    kind = serializers.ChoiceField(Adjustment.Kind.choices)
    params = serializers.DictField()
    routine_instance_id = serializers.UUIDField(allow_null=True)


class DayRoutineSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    routine_id = serializers.UUIDField(allow_null=True)
    name = serializers.CharField()
    category = serializers.ChoiceField(Category.choices)
    scheduled_start = serializers.DateTimeField(allow_null=True)
    finish_by = serializers.DateTimeField(allow_null=True)
    is_ad_hoc = serializers.BooleanField()
    adjustment = AdjustmentRefSerializer(allow_null=True)
    completions = CompletionSerializer(many=True)


class ProgressSerializer(serializers.Serializer):
    ratio = serializers.FloatField()
    total = serializers.IntegerField()
    completed = serializers.IntegerField()
    partial = serializers.IntegerField()
    skipped = serializers.IntegerField()
    in_progress = serializers.IntegerField()
    remaining = serializers.IntegerField()
    cancelled = serializers.IntegerField()


class TimingSerializer(serializers.Serializer):
    status = serializers.ChoiceField(["empty", "done", "on_track", "shifted"])
    shifted_minutes = serializers.IntegerField()
    routine_instance_id = serializers.UUIDField(allow_null=True)


class RecoverySerializer(serializers.Serializer):
    suggested = serializers.BooleanField()
    days_away = serializers.IntegerField(allow_null=True)


class DaySerializer(serializers.Serializer):
    date = serializers.DateField()
    is_today = serializers.BooleanField()
    mode = serializers.ChoiceField(DailyPlan.Mode.choices)
    energy = serializers.IntegerField(allow_null=True)
    progress = ProgressSerializer()
    focus_id = serializers.UUIDField(allow_null=True)
    timing = TimingSerializer()
    recovery = RecoverySerializer()
    adjustments = AdjustmentRefSerializer(many=True)
    routines = DayRoutineSerializer(many=True)


class DayUpdateSerializer(serializers.Serializer):
    mode = serializers.ChoiceField(DailyPlan.Mode.choices, required=False)
    energy = serializers.IntegerField(min_value=1, max_value=5, required=False)
    recovery_dismissed = serializers.BooleanField(required=False)


class CompleteSerializer(serializers.Serializer):
    actual_value = serializers.DecimalField(**D, required=False, allow_null=True, min_value=0)


class SkipSerializer(serializers.Serializer):
    reason = serializers.ChoiceField(
        ActivityCompletion.SkipReason.choices, required=False, allow_blank=True, default=""
    )


class ReflectionCreateSerializer(serializers.Serializer):
    completion_id = serializers.UUIDField(required=False, allow_null=True)
    date = serializers.DateField(required=False, allow_null=True)
    note = serializers.CharField(max_length=500, allow_blank=True, default="")
    mood = serializers.IntegerField(min_value=1, max_value=5, required=False, allow_null=True)

    def validate(self, attrs):
        if not attrs.get("completion_id") and not attrs.get("date"):
            raise serializers.ValidationError("Attach the reflection to a step or a day.")
        return attrs


class ReflectionSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    note = serializers.CharField()
    mood = serializers.IntegerField(allow_null=True)
    created_at = serializers.DateTimeField()


class AdaptationRequestSerializer(serializers.Serializer):
    budget_minutes = serializers.IntegerField(min_value=1, max_value=600, required=False, allow_null=True)


class AdaptationItemSerializer(serializers.Serializer):
    completion_id = serializers.UUIDField()
    title = serializers.CharField()
    icon = serializers.CharField()
    target_kind = serializers.CharField()
    unit = serializers.CharField()
    is_essential = serializers.BooleanField()
    priority = serializers.CharField()
    target_value = serializers.DecimalField(**D)
    planned_value = serializers.DecimalField(**D)
    status = serializers.CharField()


class AdaptationContextSerializer(serializers.Serializer):
    shifted_minutes = serializers.IntegerField()
    available_minutes = serializers.IntegerField(allow_null=True)
    finish_by = serializers.DateTimeField(allow_null=True)
    day_mode = serializers.CharField()


class AdaptationPreviewSerializer(serializers.Serializer):
    routine_instance_id = serializers.UUIDField()
    routine_name = serializers.CharField()
    mode = serializers.ChoiceField(["time_budget", "minimum"])
    budget_minutes = serializers.IntegerField(allow_null=True)
    options = serializers.ListField(child=serializers.IntegerField())
    recommended = serializers.IntegerField(allow_null=True)
    context = AdaptationContextSerializer()
    active_adjustment = AdjustmentRefSerializer(allow_null=True)
    original_minutes = serializers.IntegerField()
    planned_minutes = serializers.IntegerField()
    fits = serializers.BooleanField()
    essentials_kept = serializers.IntegerField()
    essentials_total = serializers.IntegerField()
    items = AdaptationItemSerializer(many=True)
