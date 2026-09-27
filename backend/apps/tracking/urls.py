from django.urls import path

from . import views

urlpatterns = [
    path("days/<str:date>/", views.DayView.as_view(), name="day"),
    path("completions/<uuid:pk>/start/", views.StartView.as_view(), name="completion-start"),
    path("completions/<uuid:pk>/pause/", views.PauseView.as_view(), name="completion-pause"),
    path("completions/<uuid:pk>/complete/", views.CompleteView.as_view(), name="completion-complete"),
    path("completions/<uuid:pk>/skip/", views.SkipView.as_view(), name="completion-skip"),
    path("completions/<uuid:pk>/reset/", views.ResetView.as_view(), name="completion-reset"),
    path("reflections/", views.ReflectionView.as_view(), name="reflections"),
    path(
        "routine-instances/<uuid:pk>/adaptation/preview/",
        views.AdaptationPreviewView.as_view(),
        name="adaptation-preview",
    ),
    path(
        "routine-instances/<uuid:pk>/adaptation/apply/",
        views.AdaptationApplyView.as_view(),
        name="adaptation-apply",
    ),
    path("adjustments/<uuid:pk>/revert/", views.AdjustmentRevertView.as_view(), name="adjustment-revert"),
]
