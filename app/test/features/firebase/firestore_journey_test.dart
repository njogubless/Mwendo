import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mwendo/core/config/backend.dart';
import 'package:mwendo/core/errors/app_failure.dart';
import 'package:mwendo/core/firebase/firestore_scope.dart';
import 'package:mwendo/features/auth/data/auth_repository_impl.dart';
import 'package:mwendo/features/auth/data/firebase_auth_repository.dart';
import 'package:mwendo/features/goals/data/firestore_goals_repository.dart';
import 'package:mwendo/features/goals/data/goals_repository.dart';
import 'package:mwendo/features/goals/domain/goal.dart';
import 'package:mwendo/features/insights/data/insights_repository.dart';
import 'package:mwendo/features/profile/data/firestore_profile_repository.dart';
import 'package:mwendo/features/profile/data/profile_repository.dart';
import 'package:mwendo/features/routines/data/firestore_routines_repository.dart';
import 'package:mwendo/features/routines/data/routines_repository_impl.dart';
import 'package:mwendo/features/routines/domain/routine.dart';
import 'package:mwendo/features/today/data/day_repository_impl.dart';
import 'package:mwendo/features/today/data/firestore_day_repository.dart';
import 'package:mwendo/features/today/domain/day.dart';

/// The whole Firebase data layer against in-memory Firestore/Auth: the same journey that was verified
/// against the live Django server (register → onboarding → day → partial/skip/undo → Minimum Day → time
/// budget → edit routine → goal → insights).
void main() {
  late FakeFirebaseFirestore db;
  late MockFirebaseAuth auth;
  late DateTime now;
  late FirestoreScope scope;

  setUp(() async {
    db = FakeFirebaseFirestore();
    auth = MockFirebaseAuth();
    now = DateTime.utc(2026, 11, 13, 3); // Friday 06:00 in Nairobi
    scope = FirestoreScope(db: db, auth: auth, now: () => now);
  });

  Future<void> register() => FirebaseAuthRepository(
    scope,
  ).register(email: 'Amani@Example.com', password: 'long-enough', displayName: 'Amani', timezone: 'Africa/Nairobi');

  test('providers pick the Firebase implementations', () {
    final container = ProviderContainer(
      overrides: [
        backendProvider.overrideWithValue(Backend.firebase),
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(authRepositoryProvider), isA<FirebaseAuthRepository>());
    expect(container.read(dayRepositoryProvider), isA<FirestoreDayRepository>());
    expect(container.read(routinesRepositoryProvider), isA<FirestoreRoutinesRepository>());
    expect(container.read(goalsRepositoryProvider), isA<FirestoreGoalsRepository>());
    expect(container.read(insightsRepositoryProvider), isA<FirestoreInsightsRepository>());
    expect(container.read(profileRepositoryProvider), isA<FirestoreProfileRepository>());
    expect(container.read(passwordResetMethodProvider), PasswordResetMethod.link);
  });

  test('register creates a profile; a restored session reads it back', () async {
    await register();
    final user = await FirebaseAuthRepository(scope).restoreSession();
    expect(user!.email, 'amani@example.com');
    expect(user.timezone, 'Africa/Nairobi');
    expect(user.dayStartTime, const Duration(hours: 4));
    expect(user.isOnboarded, isFalse);
  });

  test('register validates the password and time zone before creating an account', () async {
    final repo = FirebaseAuthRepository(scope);
    await expectLater(
      repo.register(email: 'a@b.co', password: 'short', displayName: '', timezone: 'UTC'),
      throwsA(isA<ValidationFailure>().having((f) => f.firstErrorFor('password'), 'password', isNotNull)),
    );
    await expectLater(
      repo.register(email: 'a@b.co', password: 'long-enough', displayName: '', timezone: 'Mars/Olympus'),
      throwsA(isA<ValidationFailure>().having((f) => f.firstErrorFor('timezone'), 'timezone', isNotNull)),
    );
  });

  test('the day journey', () async {
    await register();
    final profile = FirestoreProfileRepository(scope);
    final routines = FirestoreRoutinesRepository(scope);
    final days = FirestoreDayRepository(scope);

    // Onboarding: generate, keep the drafts, finish.
    final drafts = await routines.generate(focusAreas: ['health'], structure: 'balanced', wakeMinutes: 6 * 60);
    for (final d in drafts) {
      await routines.create(d.details, steps: d.steps);
    }
    await profile.savePreferences(focusAreas: ['health'], structure: 'balanced', wakeMinutes: 6 * 60);
    expect((await profile.completeOnboarding()).isOnboarded, isTrue);

    final list = await routines.list();
    expect(list.map((r) => r.name), ['Morning', 'Evening wind-down']);
    expect(list.first.stats.essentialSteps, greaterThan(0));

    // Today materialises from the templates.
    var day = await days.today();
    expect(day.isToday, isTrue);
    expect(day.routines.map((r) => r.name), ['Morning', 'Evening wind-down']);
    expect(day.focus!.title, 'Drink a glass of water');
    final move = day.timeline.firstWhere((s) => s.title == 'Move your body');

    day = await days.complete(day.focus!.id);
    day = await days.start(move.id);
    expect(day.focus!.id, move.id);
    day = await days.complete(move.id, actualValue: 10);
    expect(day.stepById(move.id)!.status, StepStatus.partiallyCompleted);
    final plan = day.timeline.firstWhere((s) => s.title == 'Plan your day');
    day = await days.skip(plan.id, reason: SkipReason.lowEnergy);
    day = await days.undo(plan.id);
    expect(day.stepById(plan.id)!.status, StepStatus.pending);
    await days.reflect(move.id, 'Short walk today');
    day = await days.today();
    expect(day.stepById(move.id)!.reflection, 'Short walk today');
    expect(day.progress.done, 2);

    // Minimum Day, then back to normal.
    day = await days.setMode(DayMode.minimum);
    expect(day.mode, DayMode.minimum);
    expect(day.progress.cancelled, greaterThan(0));
    day = await days.revert(day.dayAdjustment!.id);
    expect(day.mode, DayMode.normal);
    expect(day.progress.cancelled, 0);

    // A time budget on the evening routine, previewed first, then reverted.
    final evening = day.routines.firstWhere((r) => r.name == 'Evening wind-down');
    final preview = await days.preview(evening.id, budgetMinutes: 5);
    expect(preview.plannedMinutes, lessThanOrEqualTo(5));
    day = await days.applyBudget(evening.id, 5);
    final adjusted = day.routines.firstWhere((r) => r.id == evening.id);
    expect(adjusted.adjustment?.budgetMinutes, 5);
    day = await days.revert(adjusted.adjustment!.id);
    expect(day.routines.firstWhere((r) => r.id == evening.id).adjustment, isNull);

    // Editing the template re-syncs today's untouched steps; finished ones keep their snapshot.
    final morning = list.first;
    await routines.addStep(morning.id, const RoutineStep(title: 'Open the curtains', targetKind: TargetKind.check));
    day = await days.today();
    expect(day.timeline.map((s) => s.title), contains('Open the curtains'));
    expect(day.stepById(move.id)!.status, StepStatus.partiallyCompleted);

    // Reorder must name every step exactly once.
    await expectLater(
      routines.reorder(morning.id, ['nope']),
      throwsA(isA<ValidationFailure>().having((f) => f.code, 'code', 'invalid_order')),
    );

    // Insights see today's progress; routine stats pick up consistency.
    final insights = await FirestoreInsightsRepository(scope).summary(7);
    expect(insights.daysShowedUp, 1);
    expect(insights.partialWins, 1);
    expect((await routines.get(morning.id)).stats.consistency, isNotNull);

    // Tomorrow, yesterday's steps are read-only (D-024).
    now = now.add(const Duration(days: 1));
    await expectLater(days.complete(plan.id), throwsA(isA<ConflictFailure>()));
    final tomorrow = await days.today();
    expect(tomorrow.date, DateTime(2026, 11, 14));
    expect(tomorrow.progress.done, 0);
  });

  test('pausing and archiving routines update today', () async {
    await register();
    final routines = FirestoreRoutinesRepository(scope);
    final days = FirestoreDayRepository(scope);
    final r = await routines.create(
      const RoutineDetails(name: 'Stretch', category: RoutineCategory.other, daysOfWeek: [1, 2, 3, 4, 5, 6, 7]),
      steps: const [RoutineStep(title: 'Reach up', targetValue: 5)],
    );
    expect((await days.today()).routines, hasLength(1));
    await routines.setStatus(r.id, RoutineStatus.paused);
    expect((await days.today()).routines, isEmpty);
    await routines.setStatus(r.id, RoutineStatus.active);
    await routines.archive(r.id);
    expect(await routines.list(), isEmpty);
  });

  test('"Start now" adds a run for an unscheduled routine', () async {
    await register();
    final routines = FirestoreRoutinesRepository(scope);
    final r = await routines.create(
      const RoutineDetails(name: 'Weekend tidy', category: RoutineCategory.other, daysOfWeek: [6]),
      steps: const [RoutineStep(title: 'Clear the desk', targetKind: TargetKind.check)],
    );
    await routines.startNow(r.id);
    final day = await FirestoreDayRepository(scope).today();
    expect(day.routines.single.isAdHoc, isTrue);
    expect(day.focus!.title, 'Clear the desk');
  });

  test('goals, habits and measurements', () async {
    await register();
    final goals = FirestoreGoalsRepository(scope);
    final routines = FirestoreRoutinesRepository(scope);
    final days = FirestoreDayRepository(scope);

    await expectLater(goals.create(const GoalDraft(title: ' ')), throwsA(isA<ValidationFailure>()));
    var goal = await goals.create(const GoalDraft(title: 'Read 12 books', targetValue: 12, unit: 'books'));
    goal = await goals.logProgress(goal.id, value: 3, on: DateTime(2026, 11, 13));
    expect(goal.currentValue, 3);
    expect(goal.ratio, 0.25);

    await goals.createHabit(title: 'Read daily', goalId: goal.id);
    final habit = (await goals.habits()).single;
    final routine = await routines.create(
      const RoutineDetails(name: 'Evening', category: RoutineCategory.evening, daysOfWeek: [1, 2, 3, 4, 5, 6, 7]),
      steps: [
        RoutineStep(title: 'Read', targetKind: TargetKind.count, targetValue: 10, unit: 'pages', habitId: habit.id),
      ],
    );
    final day = await days.today();
    await days.complete(day.focus!.id);

    goal = await goals.get(goal.id);
    final summary = goal.habits.single;
    expect(summary.linkedSteps.single.routineId, routine.id);
    expect(summary.daysDone, 1);
    expect(summary.weeklyTarget, 7);

    goal = await goals.setStatus(goal.id, GoalStatus.achieved);
    expect(goal.status, GoalStatus.achieved);
    await goals.deleteMeasurement(goal.id, goal.measurements.single.id);
    expect((await goals.get(goal.id)).currentValue, 0);

    await goals.deleteHabit(habit.id);
    expect(await goals.habits(), isEmpty);
    expect((await routines.get(routine.id)).steps.single.habitId, isNull);

    await goals.archive(goal.id);
    expect(await goals.list(), isEmpty);
  });

  test('profile updates and account deletion', () async {
    await register();
    final profile = FirestoreProfileRepository(scope);
    final user = await profile.update(displayName: 'Amani W.', dayStartMinutes: 5 * 60);
    expect(user.displayName, 'Amani W.');
    expect(user.dayStartTime, const Duration(hours: 5));
    await expectLater(profile.update(timezone: 'Nowhere/City'), throwsA(isA<ValidationFailure>()));
    await expectLater(
      profile.changePassword(current: 'long-enough', next: 'short'),
      throwsA(isA<ValidationFailure>().having((f) => f.firstErrorFor('new_password'), 'new_password', isNotNull)),
    );

    await FirestoreRoutinesRepository(scope).create(
      const RoutineDetails(name: 'Any', category: RoutineCategory.other, daysOfWeek: [5]),
      steps: const [RoutineStep(title: 'x', targetKind: TargetKind.check)],
    );
    final uid = scope.uid;
    await profile.deleteAccount('long-enough');
    expect((await db.collection('users').doc(uid).get()).exists, isFalse);
    expect((await db.collection('users').doc(uid).collection('routines').get()).docs, isEmpty);
  });

  test('signed out, every repository says so calmly', () async {
    await expectLater(FirestoreDayRepository(scope).today(), throwsA(isA<UnauthorizedFailure>()));
    expect(await FirebaseAuthRepository(scope).restoreSession(), isNull);
  });
}
