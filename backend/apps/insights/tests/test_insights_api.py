import pytest
from django.urls import reverse
from freezegun import freeze_time

from apps.routines.tests.factories import routine_with_steps

pytestmark = pytest.mark.django_db


def _complete_first(client, **data):
    items = client.get(reverse("day", args=["today"])).json()["routines"][0]["completions"]
    client.post(reverse("completion-complete", args=[items[0]["id"]]), data, format="json")
    return items


def test_empty_history_is_honest(auth_client):
    body = auth_client.get(reverse("insights-summary")).json()
    assert body["consistency"] is None
    assert body["observations"][0]["kind"] == "learning"
    assert len(body["series"]) == 7


def test_week_summary(auth_client, user):
    routine_with_steps(user, [{"title": "a", "target_value": 10}, {"title": "b", "target_value": 10}])
    for day in ("22", "23", "24"):
        with freeze_time(f"2026-09-{day}T06:00:00Z"):
            items = _complete_first(auth_client, actual_value=5)
            auth_client.post(
                reverse("completion-skip", args=[items[1]["id"]]), {"reason": "no_time"}, format="json"
            )
    with freeze_time("2026-09-25T06:00:00Z"):
        auth_client.get(reverse("day", args=["today"]))  # planned, nothing done
    with freeze_time("2026-09-26T06:00:00Z"):
        body = auth_client.get(reverse("insights-summary"), {"days": 7}).json()

    assert (body["days_showed_up"], body["days_planned"]) == (3, 4)
    assert body["consistency"] == 0.75
    assert body["partial_wins"] == 3
    assert body["skip_reasons"] == [{"reason": "no_time", "count": 3}]
    assert body["completion_rate"] == pytest.approx(0.188, abs=0.001)
    kinds = [o["kind"] for o in body["observations"]]
    assert "consistency" in kinds and "partial" in kinds and "suggestion" in kinds
    assert body["series"][-1]["ratio"] is None  # today not planned yet (not materialised)


def test_thirty_days(auth_client):
    assert len(auth_client.get(reverse("insights-summary"), {"days": 30}).json()["series"]) == 30
