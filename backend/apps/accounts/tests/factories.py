import factory

from apps.accounts.models import Preferences, User

DEFAULT_PASSWORD = "steady-river-42"


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
        skip_postgeneration_save = True

    email = factory.Sequence(lambda n: f"person{n}@example.com")
    display_name = factory.Faker("first_name")
    timezone = "Africa/Nairobi"
    password = factory.PostGenerationMethodCall("set_password", DEFAULT_PASSWORD)

    @factory.post_generation
    def with_preferences(obj, create, extracted, **kwargs):
        if create:
            obj.save()
            Preferences.objects.get_or_create(user=obj)
