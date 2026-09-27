from decimal import Decimal

from rest_framework import serializers

from apps.goals.models import Habit

from .models import Category, Routine, RoutineActivity


class ActivitySerializer(serializers.ModelSerializer):
    habit_id = serializers.PrimaryKeyRelatedField(
        source="habit", queryset=Habit.objects.none(), allow_null=True, required=False
    )

    class Meta:
        model = RoutineActivity
        fields = [
            "id",
            "position",
            "title",
            "description",
            "icon",
            "target_kind",
            "target_value",
            "minimum_value",
            "unit",
            "is_essential",
            "priority",
            "habit_id",
        ]
        read_only_fields = ["id", "position"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["habit_id"].queryset = Habit.objects.filter(
                user=request.user, archived_at__isnull=True
            )

    def validate(self, attrs):
        kind = attrs.get(
            "target_kind", getattr(self.instance, "target_kind", RoutineActivity.TargetKind.DURATION)
        )
        if kind == RoutineActivity.TargetKind.CHECK:
            attrs["target_value"] = Decimal(1)
            attrs["minimum_value"] = None
            return attrs
        target = attrs.get("target_value", getattr(self.instance, "target_value", None))
        minimum = attrs.get("minimum_value", getattr(self.instance, "minimum_value", None))
        if target is None or target <= 0:
            raise serializers.ValidationError({"target_value": "Set a target above zero."})
        if minimum is not None and (minimum <= 0 or minimum > target):
            raise serializers.ValidationError(
                {"minimum_value": "The minimum version should be above zero and no more than the target."}
            )
        return attrs


class ActivityWriteSerializer(ActivitySerializer):
    """Nested create (routine + steps in one call, used by onboarding)."""

    class Meta(ActivitySerializer.Meta):
        fields = [f for f in ActivitySerializer.Meta.fields if f not in ("id", "position")]


class RoutineStatsSerializer(serializers.Serializer):
    steps = serializers.IntegerField()
    total_minutes = serializers.IntegerField()
    essential_steps = serializers.IntegerField()
    minimum_minutes = serializers.IntegerField()
    consistency = serializers.FloatField(allow_null=True)


class RoutineSerializer(serializers.ModelSerializer):
    activities = ActivitySerializer(many=True, read_only=True)
    stats = RoutineStatsSerializer(read_only=True)

    class Meta:
        model = Routine
        fields = [
            "id",
            "name",
            "category",
            "description",
            "days_of_week",
            "start_time",
            "finish_by",
            "status",
            "activities",
            "stats",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def validate_days_of_week(self, value):
        if any(d < 1 or d > 7 for d in value):
            raise serializers.ValidationError("Days go from 1 (Monday) to 7 (Sunday).")
        return sorted(set(value))


class RoutineCreateSerializer(RoutineSerializer):
    activities = ActivityWriteSerializer(many=True, required=False)

    class Meta(RoutineSerializer.Meta):
        pass


class ReorderSerializer(serializers.Serializer):
    ids = serializers.ListField(child=serializers.UUIDField(), allow_empty=False)


class GenerateSerializer(serializers.Serializer):
    focus_areas = serializers.ListField(
        child=serializers.CharField(max_length=32), required=False, default=list
    )
    structure = serializers.ChoiceField(["loose", "balanced", "structured"], default="balanced")
    wake_time = serializers.TimeField(required=False, allow_null=True)


class DraftRoutineSerializer(serializers.Serializer):
    name = serializers.CharField()
    category = serializers.ChoiceField(Category.choices)
    description = serializers.CharField()
    days_of_week = serializers.ListField(child=serializers.IntegerField())
    start_time = serializers.CharField(allow_null=True)
    finish_by = serializers.CharField(allow_null=True)
    activities = ActivityWriteSerializer(many=True)
