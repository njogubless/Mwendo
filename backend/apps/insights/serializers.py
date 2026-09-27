from rest_framework import serializers


class SeriesPointSerializer(serializers.Serializer):
    date = serializers.DateField()
    planned = serializers.IntegerField()
    done = serializers.IntegerField()
    ratio = serializers.FloatField(allow_null=True)


class RoutineRateSerializer(serializers.Serializer):
    routine_id = serializers.UUIDField(allow_null=True)
    name = serializers.CharField()
    steps = serializers.IntegerField()
    rate = serializers.FloatField()


class PartOfDaySerializer(serializers.Serializer):
    part = serializers.ChoiceField(["morning", "afternoon", "evening"])
    steps = serializers.IntegerField()
    rate = serializers.FloatField()


class SkipReasonCountSerializer(serializers.Serializer):
    reason = serializers.CharField()
    count = serializers.IntegerField()


class ObservationSerializer(serializers.Serializer):
    kind = serializers.CharField()
    text = serializers.CharField()


class InsightsSummarySerializer(serializers.Serializer):
    days = serializers.IntegerField()
    start = serializers.DateField()
    end = serializers.DateField()
    days_showed_up = serializers.IntegerField()
    days_planned = serializers.IntegerField()
    consistency = serializers.FloatField(allow_null=True)
    completion_rate = serializers.FloatField(allow_null=True)
    partial_wins = serializers.IntegerField()
    series = SeriesPointSerializer(many=True)
    routines = RoutineRateSerializer(many=True)
    parts_of_day = PartOfDaySerializer(many=True)
    skip_reasons = SkipReasonCountSerializer(many=True)
    observations = ObservationSerializer(many=True)
