from django.urls import path

from . import views

urlpatterns = [
    path("auth/register/", views.RegisterView.as_view(), name="auth-register"),
    path("auth/login/", views.LoginView.as_view(), name="auth-login"),
    path("auth/refresh/", views.RefreshView.as_view(), name="auth-refresh"),
    path("auth/logout/", views.LogoutView.as_view(), name="auth-logout"),
    path("auth/password/reset/", views.PasswordResetRequestView.as_view(), name="auth-password-reset"),
    path(
        "auth/password/reset/confirm/",
        views.PasswordResetConfirmView.as_view(),
        name="auth-password-reset-confirm",
    ),
    path("me/", views.MeView.as_view(), name="me"),
    path("me/password/", views.PasswordChangeView.as_view(), name="me-password"),
    path("me/preferences/", views.PreferencesView.as_view(), name="me-preferences"),
    path("me/onboarding/complete/", views.CompleteOnboardingView.as_view(), name="me-onboarding-complete"),
]
