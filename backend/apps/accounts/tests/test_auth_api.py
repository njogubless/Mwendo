import pytest
from django.urls import reverse
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken

from apps.accounts.models import Preferences, User

from .factories import DEFAULT_PASSWORD, UserFactory

pytestmark = pytest.mark.django_db


def register(client, **overrides):
    payload = {
        "email": "Zawadi@Example.com",
        "password": DEFAULT_PASSWORD,
        "display_name": "Zawadi",
        "timezone": "Africa/Nairobi",
        **overrides,
    }
    return client.post(reverse("auth-register"), payload)


class TestRegister:
    def test_creates_user_with_preferences_and_returns_tokens(self, api_client):
        response = register(api_client)

        assert response.status_code == 201
        body = response.json()
        assert {"access", "refresh", "user"} <= body.keys()
        assert body["user"]["email"] == "zawadi@example.com"
        assert body["user"]["is_onboarded"] is False
        user = User.objects.get(email="zawadi@example.com")
        assert Preferences.objects.filter(user=user).exists()
        assert user.check_password(DEFAULT_PASSWORD)

    def test_rejects_duplicate_email_case_insensitively(self, api_client):
        UserFactory(email="zawadi@example.com")

        response = register(api_client, email="ZAWADI@example.com")

        assert response.status_code == 400
        assert response.json()["error"]["code"] == "validation_error"
        assert "email" in response.json()["error"]["details"]

    @pytest.mark.parametrize("password", ["short", "password123", "12345678901"])
    def test_rejects_weak_passwords(self, api_client, password):
        response = register(api_client, password=password)

        assert response.status_code == 400
        assert "password" in response.json()["error"]["details"]

    def test_rejects_unknown_timezone(self, api_client):
        response = register(api_client, timezone="Mars/Olympus")

        assert response.status_code == 400
        assert "timezone" in response.json()["error"]["details"]


class TestLogin:
    def test_returns_tokens_for_valid_credentials_with_any_email_case(self, api_client):
        UserFactory(email="amani@example.com")

        response = api_client.post(
            reverse("auth-login"), {"email": " Amani@Example.com ", "password": DEFAULT_PASSWORD}
        )

        assert response.status_code == 200
        assert response.json()["user"]["email"] == "amani@example.com"

    def test_wrong_password_gives_calm_generic_error(self, api_client):
        UserFactory(email="amani@example.com")

        response = api_client.post(reverse("auth-login"), {"email": "amani@example.com", "password": "nope"})

        assert response.status_code == 401
        error = response.json()["error"]
        assert error["code"] == "no_active_account"
        assert "password" not in error["details"]

    def test_inactive_user_cannot_log_in(self, api_client):
        UserFactory(email="amani@example.com", is_active=False)

        response = api_client.post(
            reverse("auth-login"), {"email": "amani@example.com", "password": DEFAULT_PASSWORD}
        )

        assert response.status_code == 401


class TestRefreshAndLogout:
    def test_refresh_rotates_and_old_refresh_is_rejected(self, api_client):
        tokens = register(api_client).json()

        first = api_client.post(reverse("auth-refresh"), {"refresh": tokens["refresh"]})
        replay = api_client.post(reverse("auth-refresh"), {"refresh": tokens["refresh"]})

        assert first.status_code == 200
        assert first.json()["refresh"] != tokens["refresh"]
        assert replay.status_code == 401
        assert replay.json()["error"]["code"] == "token_not_valid"
        assert "ErrorDetail" not in replay.json()["error"]["message"]

    def test_logout_blacklists_refresh_token(self, api_client):
        tokens = register(api_client).json()
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {tokens['access']}")

        response = api_client.post(reverse("auth-logout"), {"refresh": tokens["refresh"]})

        assert response.status_code == 204
        assert BlacklistedToken.objects.count() == 1
        api_client.credentials()
        assert api_client.post(reverse("auth-refresh"), {"refresh": tokens["refresh"]}).status_code == 401

    def test_cannot_log_out_someone_elses_session(self, api_client):
        victim_tokens = register(api_client).json()
        attacker = register(api_client, email="other@example.com").json()
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {attacker['access']}")

        response = api_client.post(reverse("auth-logout"), {"refresh": victim_tokens["refresh"]})

        assert response.status_code == 400
        assert BlacklistedToken.objects.count() == 0

    def test_logout_requires_authentication(self, api_client):
        response = api_client.post(reverse("auth-logout"), {"refresh": "x"})

        assert response.status_code == 401
        assert response.json()["error"]["code"] == "not_authenticated"
