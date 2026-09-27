from django.db import transaction
from django.utils import timezone
from django.utils.decorators import method_decorator
from drf_spectacular.utils import extend_schema
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from apps.core.exceptions import DomainError

from .models import Preferences
from .serializers import (
    AccountDeleteSerializer,
    AuthTokensSerializer,
    LoginSerializer,
    LogoutSerializer,
    PasswordChangeSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    PreferencesSerializer,
    RegisterSerializer,
    UserSerializer,
)
from .services import confirm_password_reset, register_user, request_password_reset


class AuthThrottleMixin:
    throttle_scope = "auth"

    def get_throttles(self):
        from rest_framework.throttling import ScopedRateThrottle

        return [ScopedRateThrottle()]


class RegisterView(AuthThrottleMixin, APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(request=RegisterSerializer, responses={201: AuthTokensSerializer})
    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = register_user(**serializer.validated_data)
        return Response(AuthTokensSerializer.for_user(user), status=status.HTTP_201_CREATED)


class LoginView(AuthThrottleMixin, TokenObtainPairView):
    serializer_class = LoginSerializer
    authentication_classes = []

    @extend_schema(responses={200: AuthTokensSerializer})
    def post(self, request, *args, **kwargs):
        return super().post(request, *args, **kwargs)


class RefreshView(AuthThrottleMixin, TokenRefreshView):
    authentication_classes = []


class LogoutView(APIView):
    """Blacklists the given refresh token. Access tokens expire on their own (15 min)."""

    @extend_schema(request=LogoutSerializer, responses={204: None})
    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            token = RefreshToken(serializer.validated_data["refresh"])
            if str(token.get("user_id")) != str(request.user.id):
                raise DomainError(
                    "That session doesn't belong to you.", code="invalid_token", status_code=400
                )
            token.blacklist()
        except TokenError:
            pass  # Already expired or blacklisted: logging out is still a success.
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    http_method_names = ["get", "patch", "delete"]

    def get_object(self):
        return self.request.user

    @extend_schema(request=AccountDeleteSerializer, responses={204: None})
    def delete(self, request):
        """Permanently deletes the account and all its data."""
        serializer = AccountDeleteSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        request.user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetRequestView(AuthThrottleMixin, APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(request=PasswordResetRequestSerializer, responses={202: None})
    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        request_password_reset(serializer.validated_data["email"])
        return Response(status=status.HTTP_202_ACCEPTED)


@method_decorator(transaction.non_atomic_requests, name="dispatch")
class PasswordResetConfirmView(AuthThrottleMixin, APIView):
    permission_classes = [permissions.AllowAny]
    authentication_classes = []

    @extend_schema(request=PasswordResetConfirmSerializer, responses={200: AuthTokensSerializer})
    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        user = confirm_password_reset(data["email"], data["code"], data["new_password"])
        return Response(AuthTokensSerializer.for_user(user))


class PasswordChangeView(APIView):
    @extend_schema(request=PasswordChangeSerializer, responses={204: None})
    def post(self, request):
        serializer = PasswordChangeSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        request.user.set_password(serializer.validated_data["new_password"])
        request.user.save(update_fields=["password", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class PreferencesView(generics.RetrieveUpdateAPIView):
    serializer_class = PreferencesSerializer
    http_method_names = ["get", "put", "patch"]

    def get_object(self):
        prefs, _ = Preferences.objects.get_or_create(user=self.request.user)
        return prefs


class CompleteOnboardingView(APIView):
    @extend_schema(request=None, responses={200: UserSerializer})
    def post(self, request):
        user = request.user
        if user.onboarding_completed_at is None:
            user.onboarding_completed_at = timezone.now()
            user.save(update_fields=["onboarding_completed_at", "updated_at"])
        return Response(UserSerializer(user).data)
