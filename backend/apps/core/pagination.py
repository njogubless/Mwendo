from rest_framework.pagination import CursorPagination, PageNumberPagination


class DefaultPagination(PageNumberPagination):
    page_size = 50
    page_size_query_param = "page_size"
    max_page_size = 200


class HistoryCursorPagination(CursorPagination):
    """For append-only history (completions, reflections): stable under inserts."""

    page_size = 50
    ordering = "-created_at"
