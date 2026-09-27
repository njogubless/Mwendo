from django.shortcuts import get_object_or_404
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.tracking.selectors import build_day
from apps.tracking.serializers import DaySerializer

from . import services
from .generator import generate_routines
from .models import Routine, RoutineActivity
from .selectors import attach_stats, routines_for
from .serializers import (
    ActivitySerializer,
    DraftRoutineSerializer,
    GenerateSerializer,
    ReorderSerializer,
    RoutineCreateSerializer,
    RoutineSerializer,
)


class RoutineViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    mixins.UpdateModelMixin,
    mixins.DestroyModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = RoutineSerializer
    pagination_class = None
    http_method_names = ["get", "post", "patch", "delete"]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Routine.objects.none()
        params = self.request.query_params
        return routines_for(
            self.request.user,
            include_archived=params.get("include_archived") == "true" or self.action != "list",
            category=params.get("category"),
        )

    def get_serializer_class(self):
        return RoutineCreateSerializer if self.action == "create" else RoutineSerializer

    def _out(self, routine):
        routine = routines_for(self.request.user, include_archived=True).get(pk=routine.pk)
        return RoutineSerializer(
            attach_stats(self.request.user, [routine])[0], context=self.get_serializer_context()
        )

    @extend_schema(
        parameters=[
            OpenApiParameter("category", str, required=False),
            OpenApiParameter("include_archived", bool, required=False),
        ]
    )
    def list(self, request):
        routines = attach_stats(request.user, list(self.get_queryset()))
        return Response(RoutineSerializer(routines, many=True, context=self.get_serializer_context()).data)

    def retrieve(self, request, pk=None):
        return Response(self._out(self.get_object()).data)

    def create(self, request):
        serializer = RoutineCreateSerializer(data=request.data, context=self.get_serializer_context())
        serializer.is_valid(raise_exception=True)
        routine = services.create_routine(request.user, **serializer.validated_data)
        return Response(self._out(routine).data, status=status.HTTP_201_CREATED)

    def partial_update(self, request, pk=None):
        routine = self.get_object()
        serializer = RoutineSerializer(routine, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        services.update_routine(routine, **serializer.validated_data)
        return Response(self._out(routine).data)

    @extend_schema(description="Archives the routine. History is kept.")
    def destroy(self, request, pk=None):
        services.archive_routine(self.get_object())
        return Response(status=status.HTTP_204_NO_CONTENT)

    @extend_schema(
        request=ActivitySerializer, responses={201: ActivitySerializer, 200: ActivitySerializer(many=True)}
    )
    @action(detail=True, methods=["get", "post"])
    def activities(self, request, pk=None):
        routine = self.get_object()
        if request.method == "GET":
            data = ActivitySerializer(
                routine.activities.all(), many=True, context=self.get_serializer_context()
            ).data
            return Response(data)
        serializer = ActivitySerializer(data=request.data, context=self.get_serializer_context())
        serializer.is_valid(raise_exception=True)
        activity = services.add_activity(routine, **serializer.validated_data)
        return Response(ActivitySerializer(activity).data, status=status.HTTP_201_CREATED)

    @extend_schema(request=ReorderSerializer, responses=RoutineSerializer)
    @action(detail=True, methods=["post"])
    def reorder(self, request, pk=None):
        routine = self.get_object()
        serializer = ReorderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.reorder_activities(routine, serializer.validated_data["ids"])
        return Response(self._out(routine).data)

    @extend_schema(request=None, responses=DaySerializer)
    @action(detail=True, methods=["post"])
    def start(self, request, pk=None):
        """Start this routine now, outside its schedule. Returns today's plan."""
        instance = services.start_now(self.get_object())
        return Response(DaySerializer(build_day(request.user, instance.local_date)).data)

    @extend_schema(request=GenerateSerializer, responses=DraftRoutineSerializer(many=True))
    @action(detail=False, methods=["post"])
    def generate(self, request):
        """Propose first routines from onboarding answers. Saves nothing."""
        serializer = GenerateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(generate_routines(**serializer.validated_data))


class ActivityDetailView(APIView):
    def _get(self, request, routine_pk, pk):
        return get_object_or_404(
            RoutineActivity.objects.select_related("routine"),
            pk=pk,
            routine_id=routine_pk,
            user=request.user,
            archived_at__isnull=True,
        )

    @extend_schema(request=ActivitySerializer, responses=ActivitySerializer)
    def patch(self, request, routine_pk, pk):
        activity = self._get(request, routine_pk, pk)
        serializer = ActivitySerializer(
            activity, data=request.data, partial=True, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        services.update_activity(activity, **serializer.validated_data)
        return Response(ActivitySerializer(activity).data)

    @extend_schema(responses={204: None})
    def delete(self, request, routine_pk, pk):
        services.archive_activity(self._get(request, routine_pk, pk))
        return Response(status=status.HTTP_204_NO_CONTENT)
