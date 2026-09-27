from rest_framework.routers import SimpleRouter

from .views import GoalViewSet, HabitViewSet

router = SimpleRouter()
router.register("goals", GoalViewSet, basename="goal")
router.register("habits", HabitViewSet, basename="habit")
urlpatterns = router.urls
