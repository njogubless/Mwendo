import datetime

import pytest
from django.urls import reverse

pytestmark = pytest.mark.django_db


def test_me_returns_only_the_authenticated_user(auth_client, user):
    response = auth_client.get(reverse("me"))

    assert response.status_code == 200
    assert response.json()["id"] == str(user.id)


def test_me_patch_updates_profile_but_not_email(auth_client, user):
    response = auth_client.patch(
        reverse("me"), {"display_name": "Wanjiru", "day_start_time": "05:00", "email": "hijack@example.com"}
    )

    assert response.status_code == 200
    user.refresh_from_db()
    assert user.display_name == "Wanjiru"
    assert user.day_start_time == datetime.time(5, 0)
    assert user.email != "hijack@example.com"


def test_me_rejects_invalid_timezone(auth_client):
    response = auth_client.patch(reverse("me"), {"timezone": "Nowhere/Land"})

    assert response.status_code == 400


def test_preferences_round_trip(auth_client):
    payload = {
        "structure": "structured",
        "wake_time": "06:30:00",
        "focus_areas": ["health", "learning"],
        "ideal_day": {"morning": "movement"},
    }

    put = auth_client.put(reverse("me-preferences"), payload, format="json")
    get = auth_client.get(reverse("me-preferences"))

    assert put.status_code == 200
    assert get.json() == payload


def test_complete_onboarding_is_idempotent(auth_client, user):
    first = auth_client.post(reverse("me-onboarding-complete"))
    user.refresh_from_db()
    completed_at = user.onboarding_completed_at
    second = auth_client.post(reverse("me-onboarding-complete"))
    user.refresh_from_db()

    assert first.json()["is_onboarded"] is True
    assert second.status_code == 200
    assert user.onboarding_completed_at == completed_at


def test_me_requires_authentication(api_client):
    assert api_client.get(reverse("me")).status_code == 401
