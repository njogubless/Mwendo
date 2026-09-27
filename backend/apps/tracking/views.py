import datetime as dt

from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.clock import user_today
from apps.core.exceptions import DomainError
from apps.core.idempotency import idempotent

from . import services
from .models import RoutineInstance
from .selectors import build_adaptation_preview, build_day
from .serializers import (
    AdaptationPreviewSerializer,
    AdaptationRequestSerializer,
    CompleteSerializer,
    DaySerializer,
    DayUpdateSerializer,
    ReflectionCreateSerializer,
    ReflectionSerializer,
    SkipSerializer,
)


def _parse_day(user, value: str) -> dt.date:
    if value == "today":
        return user_today(user)
    try:
        return dt.date.fromisoformat(value)
    except ValueError as exc:
        raise DomainError(
            "Use a date like 2026-09-26 or 'today'.", code="invalid_date", status_code=400
        ) from exc


def _day_response(user, completion=None, day=None):
    day = day or (completion.routine_instance.local_date if completion else user_today(user))
    return Response(DaySerializer(build_day(user, day)).data)


class DayView(APIView):
    """The user's day: routines, steps, progress and what to focus on now. `date` may be `today`."""

    @extend_schema(responses=DaySerializer)
    def get(self, request, date):
        return Response(DaySerializer(build_day(request.user, _parse_day(request.user, date))).data)

    @extend_schema(request=DayUpdateSerializer, responses=DaySerializer)
    def patch(self, request, date):
        day = _parse_day(request.user, date)
        serializer = DayUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.update_day(request.user, day, **serializer.validated_data)
        return _day_response(request.user, day=day)


class _CompletionAction(APIView):
    request_serializer = None

    def perform(self, request, pk, data):
        raise NotImplementedError

    @idempotent
    def post(self, request, pk):
        data = {}
        if self.request_serializer:
            serializer = self.request_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            data = serializer.validated_data
        completion = self.perform(request, pk, data)
        return _day_response(request.user, completion)


@extend_schema(request=None, responses=DaySerializer)
class StartView(_CompletionAction):
    def perform(self, request, pk, data):
        return services.start(request.user, pk)


@extend_schema(request=None, responses=DaySerializer)
class PauseView(_CompletionAction):
    def perform(self, request, pk, data):
        return services.pause(request.user, pk)


@extend_schema(request=CompleteSerializer, responses=DaySerializer)
class CompleteView(_CompletionAction):
    request_serializer = CompleteSerializer

    def perform(self, request, pk, data):
        return services.complete(request.user, pk, data.get("actual_value"))


@extend_schema(request=SkipSerializer, responses=DaySerializer)
class SkipView(_CompletionAction):
    request_serializer = SkipSerializer

    def perform(self, request, pk, data):
        return services.skip(request.user, pk, data.get("reason", ""))


@extend_schema(request=None, responses=DaySerializer)
class ResetView(_CompletionAction):
    def perform(self, request, pk, data):
        return services.reset(request.user, pk)


class ReflectionView(APIView):
    @extend_schema(request=ReflectionCreateSerializer, responses={201: ReflectionSerializer})
    def post(self, request):
        serializer = ReflectionCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        reflection = services.add_reflection(
            request.user,
            completion_id=data.get("completion_id"),
            day=data.get("date"),
            note=data.get("note", ""),
            mood=data.get("mood"),
        )
        return Response(ReflectionSerializer(reflection).data, status=201)


class AdaptationPreviewView(APIView):
    """What the routine would look like under a time budget (or as a Minimum Day). Changes nothing."""

    @extend_schema(
        parameters=[
            OpenApiParameter("budget_minutes", int, required=False),
            OpenApiParameter("mode", str, enum=["time_budget", "minimum"], required=False),
        ],
        responses=AdaptationPreviewSerializer,
    )
    def get(self, request, pk):
        get_object_or_404(RoutineInstance, pk=pk, user=request.user)
        budget = request.query_params.get("budget_minutes")
        try:
            budget = int(budget) if budget else None
        except ValueError as exc:
            raise DomainError(
                "budget_minutes must be a number.", code="invalid_budget", status_code=400
            ) from exc
        preview = build_adaptation_preview(
            request.user, pk, budget_minutes=budget, minimum=request.query_params.get("mode") == "minimum"
        )
        return Response(AdaptationPreviewSerializer(preview).data)


class AdaptationApplyView(APIView):
    """Apply a time budget to a routine instance (the user approved the preview)."""

    @extend_schema(request=AdaptationRequestSerializer, responses=DaySerializer)
    @idempotent
    def post(self, request, pk):
        get_object_or_404(RoutineInstance, pk=pk, user=request.user)
        serializer = AdaptationRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        if not serializer.validated_data.get("budget_minutes"):
            raise DomainError("Choose how much time you have.", code="budget_required", status_code=400)
        services.apply_time_budget(request.user, pk, serializer.validated_data["budget_minutes"])
        return _day_response(request.user)


class AdjustmentRevertView(APIView):
    """Restore the original plan ("Restore full routine anyway")."""

    @extend_schema(request=None, responses=DaySerializer)
    def post(self, request, pk):
        from .models import Adjustment

        get_object_or_404(Adjustment, pk=pk, user=request.user)
        services.revert_adjustment(request.user, pk)
        return _day_response(request.user)
