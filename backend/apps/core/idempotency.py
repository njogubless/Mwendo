"""Safe retries for state-changing actions (`Idempotency-Key` header).

The first response for a (user, key) pair is stored; replays return it unchanged. This lets the app retry
after a timeout — and, later, replay an offline outbox — without double-applying a completion.
"""

import functools
import json
import re

from django.core.serializers.json import DjangoJSONEncoder
from django.db import IntegrityError, models, transaction
from rest_framework.renderers import JSONRenderer
from rest_framework.response import Response

from .models import TimeStampedModel

_VALID = re.compile(r"^[A-Za-z0-9\-_]{8,80}$")


class IdempotencyKey(TimeStampedModel):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE)
    key = models.CharField(max_length=80)
    status_code = models.PositiveSmallIntegerField()
    response = models.JSONField(encoder=DjangoJSONEncoder)

    class Meta:
        constraints = [models.UniqueConstraint(fields=["user", "key"], name="core_idempotency_user_key")]


def idempotent(view_method):
    @functools.wraps(view_method)
    def wrapper(self, request, *args, **kwargs):
        key = request.headers.get("Idempotency-Key", "")
        if not _VALID.match(key):
            return view_method(self, request, *args, **kwargs)
        stored = IdempotencyKey.objects.filter(user=request.user, key=key).first()
        if stored:
            return Response(stored.response, status=stored.status_code)
        response = view_method(self, request, *args, **kwargs)
        if 200 <= response.status_code < 300:
            try:
                with transaction.atomic():
                    # Store exactly what the client received so a replay is byte-for-byte equivalent.
                    rendered = json.loads(JSONRenderer().render(response.data))
                    IdempotencyKey.objects.create(
                        user=request.user, key=key, status_code=response.status_code, response=rendered
                    )
            except IntegrityError:
                pass
        return response

    return wrapper
