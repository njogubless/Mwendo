from .base import *  # noqa: F403
from .base import env

DEBUG = env.bool("DJANGO_DEBUG", default=True)
# Development only: accept phones/emulators/browsers on your network (run `runserver 0.0.0.0:8001`).
# Production (prod.py) still requires explicit DJANGO_ALLOWED_HOSTS and CORS origins.
ALLOWED_HOSTS = env.list("DJANGO_ALLOWED_HOSTS", default=["*"])
CORS_ALLOW_ALL_ORIGINS = True
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
