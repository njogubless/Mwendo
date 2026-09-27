from rest_framework import serializers

from .models import Goal, Habit, Measurement


class LinkedStepSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    title = serializers.CharField()
    routine_id = serializers.UUIDField()


class HabitSummarySerializer(serializers.Serializer):
    id = serializers.UUIDField()
    title = serializers.CharField()
    frequency_per = serializers.ChoiceField(Habit.Per.choices)
    frequency_times = serializers.IntegerField()
    days_done = serializers.IntegerField()
    days_planned = serializers.IntegerField()
    weekly_target = serializers.IntegerField()
    linked_steps = LinkedStepSerializer(many=True)


class GoalProgressSerializer(serializers.Serializer):
    current_value = serializers.DecimalField(max_digits=10, decimal_places=2)
    ratio = serializers.FloatField(allow_null=True)


class MeasurementSerializer(serializers.ModelSerializer):
    class Meta:
        model = Measurement
        fields = ["id", "value", "recorded_on", "note", "created_at"]
        read_only_fields = ["id", "created_at"]

    def validate_value(self, value):
        if value == 0:
            raise serializers.ValidationError("Log an amount other than zero.")
        return value


class GoalSerializer(serializers.ModelSerializer):
    progress = GoalProgressSerializer(read_only=True)
    habits = HabitSummarySerializer(source="habit_rows", many=True, read_only=True)
    measurements = MeasurementSerializer(many=True, read_only=True)

    class Meta:
        model = Goal
        fields = [
            "id",
            "title",
            "description",
            "area",
            "target_value",
            "unit",
            "target_date",
            "status",
            "achieved_at",
            "progress",
            "habits",
            "measurements",
            "created_at",
        ]
        read_only_fields = ["id", "achieved_at", "created_at"]

    def validate_target_value(self, value):
        if value is not None and value <= 0:
            raise serializers.ValidationError("Set a target above zero, or leave it empty.")
        return value


class HabitSerializer(serializers.ModelSerializer):
    goal_id = serializers.PrimaryKeyRelatedField(
        source="goal", queryset=Goal.objects.none(), allow_null=True, required=False
    )

    class Meta:
        model = Habit
        fields = ["id", "goal_id", "title", "frequency_per", "frequency_times", "created_at"]
        read_only_fields = ["id", "created_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["goal_id"].queryset = Goal.objects.filter(user=request.user)

    def validate(self, attrs):
        per = attrs.get("frequency_per", getattr(self.instance, "frequency_per", Habit.Per.DAY))
        times = attrs.get("frequency_times", getattr(self.instance, "frequency_times", 1))
        if times < 1 or (per == Habit.Per.WEEK and times > 7) or (per == Habit.Per.DAY and times > 10):
            raise serializers.ValidationError({"frequency_times": "Choose a realistic number of times."})
        return attrs
