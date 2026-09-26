from django.contrib.auth import password_validation
from django.contrib.auth.models import update_last_login
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Preferences, User
from .validators import validate_timezone


class UserSerializer(serializers.ModelSerializer):
    is_onboarded = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = ["id", "email", "display_name", "timezone", "day_start_time", "is_onboarded", "date_joined"]
        read_only_fields = ["id", "email", "is_onboarded", "date_joined"]


class PreferencesSerializer(serializers.ModelSerializer):
    class Meta:
        model = Preferences
        fields = ["structure", "wake_time", "focus_areas", "ideal_day"]


class AuthTokensSerializer(serializers.Serializer):
    """Response shape shared by register and login."""

    access = serializers.CharField()
    refresh = serializers.CharField()
    user = UserSerializer()

    @staticmethod
    def for_user(user: User) -> dict:
        refresh = RefreshToken.for_user(user)
        update_last_login(None, user)
        return {
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "user": UserSerializer(user).data,
        }


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField(max_length=254)
    password = serializers.CharField(write_only=True, trim_whitespace=False, style={"input_type": "password"})
    display_name = serializers.CharField(max_length=80, required=False, allow_blank=True, default="")
    timezone = serializers.CharField(
        max_length=64, required=False, default="UTC", validators=[validate_timezone]
    )

    def validate_email(self, value):
        value = value.strip().lower()
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError(
                "An account with this email already exists.", code="email_taken"
            )
        return value

    def validate(self, attrs):
        candidate = User(email=attrs["email"], display_name=attrs.get("display_name", ""))
        try:
            password_validation.validate_password(attrs["password"], user=candidate)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)}) from exc
        return attrs


class LoginSerializer(TokenObtainPairSerializer):
    default_error_messages = {"no_active_account": "That email and password don't match an account."}

    def validate(self, attrs):
        attrs[self.username_field] = attrs[self.username_field].strip().lower()
        super().validate(attrs)
        return AuthTokensSerializer.for_user(self.user)


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()
