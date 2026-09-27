from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from .selectors import build_summary
from .serializers import InsightsSummarySerializer


class InsightsSummaryView(APIView):
    @extend_schema(
        parameters=[OpenApiParameter("days", int, enum=[7, 30])], responses=InsightsSummarySerializer
    )
    def get(self, request):
        days = 30 if request.query_params.get("days") == "30" else 7
        return Response(InsightsSummarySerializer(build_summary(request.user, days)).data)
