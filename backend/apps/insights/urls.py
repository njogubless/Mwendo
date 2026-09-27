from django.urls import path

from .views import InsightsSummaryView

urlpatterns = [path("insights/summary/", InsightsSummaryView.as_view(), name="insights-summary")]
