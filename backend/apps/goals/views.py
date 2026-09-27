from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from apps.core.permissions import OwnedModelViewSet

from .models import Goal, Habit, Measurement
from .selectors import attach_progress, goals_for
from .serializers import GoalSerializer, HabitSerializer, MeasurementSerializer


class GoalViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = GoalSerializer
    pagination_class = None
    http_method_names = ["get", "post", "patch", "delete"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Goal.objects.none()
        return goals_for(self.request.user, include_archived=self.action != "list")

    def _out(self, goal):
        goal = goals_for(self.request.user, include_archived=True).get(pk=goal.pk)
        return GoalSerializer(attach_progress(self.request.user, [goal])[0]).data

    def list(self, request):
        goals = attach_progress(request.user, list(self.get_queryset()))
        return Response(GoalSerializer(goals, many=True).data)

    def retrieve(self, request, pk=None):
        return Response(self._out(self.get_object()))

    def create(self, request):
        serializer = GoalSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        goal = serializer.save(user=request.user)
        return Response(self._out(goal), status=status.HTTP_201_CREATED)

    def partial_update(self, request, pk=None):
        goal = self.get_object()
        serializer = GoalSerializer(goal, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data.get("status")
        if new_status == Goal.Status.ACHIEVED and goal.achieved_at is None:
            serializer.validated_data["achieved_at"] = timezone.now()
        elif new_status and new_status != Goal.Status.ACHIEVED:
            serializer.validated_data["achieved_at"] = None
        serializer.save()
        return Response(self._out(goal))

    @extend_schema(description="Archives the goal. Its habits stay linked to your steps.")
    def destroy(self, request, pk=None):
        goal = self.get_object()
        goal.status = Goal.Status.ARCHIVED
        goal.save(update_fields=["status", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(request=MeasurementSerializer, responses={201: GoalSerializer})
    @action(detail=True, methods=["post"])
    def measurements(self, request, pk=None):
        goal = self.get_object()
        serializer = MeasurementSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save(user=request.user, goal=goal)
        return Response(self._out(goal), status=status.HTTP_201_CREATED)

    @extend_schema(
        request=None,
        responses={204: None},
        parameters=[OpenApiParameter("measurement_id", OpenApiTypes.UUID, OpenApiParameter.PATH)],
    )
    @action(detail=True, methods=["delete"], url_path=r"measurements/(?P<measurement_id>[0-9a-f-]{36})")
    def delete_measurement(self, request, pk=None, measurement_id=None):
        goal = self.get_object()
        get_object_or_404(Measurement, pk=measurement_id, goal=goal, user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class HabitViewSet(OwnedModelViewSet):
    serializer_class = HabitSerializer
    queryset = Habit.objects.filter(archived_at__isnull=True)
    pagination_class = None
    http_method_names = ["get", "post", "patch", "delete"]

    def perform_destroy(self, instance):
        instance.archived_at = timezone.now()
        instance.save(update_fields=["archived_at", "updated_at"])
        instance.activities.update(habit=None)
