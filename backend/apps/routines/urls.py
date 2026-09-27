from django.urls import path
from rest_framework.routers import SimpleRouter

from .views import ActivityDetailView, RoutineViewSet

router = SimpleRouter()
router.register("routines", RoutineViewSet, basename="routine")

urlpatterns = [
    path(
        "routines/<uuid:routine_pk>/activities/<uuid:pk>/",
        ActivityDetailView.as_view(),
        name="routine-activity-detail",
    ),
    *router.urls,
]
