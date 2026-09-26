import pytest
from django.urls import reverse
from rest_framework import serializers
from rest_framework.test import APIRequestFactory

from apps.core.exceptions import DomainError, api_exception_handler

pytestmark = pytest.mark.django_db


def test_health_reports_database(api_client):
    response = api_client.get(reverse("health"))

    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_request_id_is_generated_and_echoed(api_client):
    generated = api_client.get(reverse("health"))
    echoed = api_client.get(reverse("health"), HTTP_X_REQUEST_ID="abc12345-client")
    rejected = api_client.get(reverse("health"), HTTP_X_REQUEST_ID="bad id <script>")

    assert len(generated["X-Request-ID"]) == 32
    assert echoed["X-Request-ID"] == "abc12345-client"
    assert rejected["X-Request-ID"] != "bad id <script>"


def test_not_found_uses_error_envelope():
    from django.http import Http404

    response = api_exception_handler(Http404("internal detail"), _context())

    assert response.status_code == 404
    assert response.data["error"]["code"] == "not_found"
    assert "internal" not in str(response.data)


def _context():
    return {"request": APIRequestFactory().get("/")}


def test_domain_error_maps_to_conflict_with_code():
    response = api_exception_handler(DomainError("Already done.", code="already_completed"), _context())

    assert response.status_code == 409
    assert response.data["error"]["code"] == "already_completed"
    assert response.data["error"]["message"] == "Already done."


def test_validation_error_details_are_preserved():
    exc = serializers.ValidationError({"title": ["This field is required."]})

    response = api_exception_handler(exc, _context())

    assert response.status_code == 400
    assert response.data["error"]["details"] == {"title": ["This field is required."]}


def test_unexpected_errors_return_safe_500():
    response = api_exception_handler(RuntimeError("secret internals"), _context())

    assert response.status_code == 500
    assert "secret" not in str(response.data)
    assert response.data["error"]["code"] == "server_error"


def test_openapi_schema_is_served(api_client, user):
    api_client.force_authenticate(user)

    response = api_client.get(reverse("schema"))

    assert response.status_code == 200
    assert b"/api/v1/auth/login/" in response.content
