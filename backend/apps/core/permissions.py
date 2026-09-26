from rest_framework import permissions, viewsets


class IsOwner(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        return getattr(obj, "user_id", None) == request.user.id


class OwnedModelViewSet(viewsets.ModelViewSet):
    """Scopes every query to the requesting user; other users' objects 404 rather than 403.

    Subclasses set `queryset` (or override `get_base_queryset`) and never need to filter by user themselves.
    """

    permission_classes = [permissions.IsAuthenticated, IsOwner]

    def get_base_queryset(self):
        return super().get_queryset()

    def get_queryset(self):
        return self.get_base_queryset().filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
