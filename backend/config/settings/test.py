from .base import *  # noqa: F403
from .base import REST_FRAMEWORK

DEBUG = False
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]  # speed only
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
REST_FRAMEWORK = {
    **REST_FRAMEWORK,
    # freezegun breaks DRF's class-level throttle timer; auth views keep their own scoped throttle.
    "DEFAULT_THROTTLE_CLASSES": [],
    "DEFAULT_THROTTLE_RATES": {"user": "10000/min", "auth": "1000/min"},
}
