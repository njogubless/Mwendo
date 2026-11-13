import '../../../core/firebase/firebase_failure_mapper.dart';
import '../../../core/firebase/firestore_scope.dart';
import '../../routines/data/firestore_routines_repository.dart';
import '../../routines/domain/routine.dart';
import '../domain/day.dart';
import '../domain/day_repository.dart';
import '../domain/engine/day_engine.dart';
import '../domain/engine/day_record.dart';
import 'firestore/day_store.dart';

/// Today on Firestore. Each action loads today's document, applies the rule in [DayEngine], saves the
/// document and returns the refreshed day — the same contract as the Django endpoints (D-020), so
/// `TodayController` and every screen work unchanged.
class FirestoreDayRepository implements DayRepository {
  FirestoreDayRepository(this.scope) : _days = DayStore(scope);

  final FirestoreScope scope;
  final DayStore _days;

  Future<List<Routine>> _routines() async => [
    for (final d in (await scope.routines.get()).docs) routineFromDoc(d.id, d.data()),
  ];

  /// Loads (and materialises) today, runs [change] when given, saves if anything changed, returns the day.
  Future<Day> _today([void Function(DayEngine engine, DayRecord day)? change]) => guardFirebase(() async {
    final ctx = await scope.context();
    final engine = DayEngine(ctx.clock);
    final today = ctx.clock.today();
    final (:day, :offline) = await _days.load(today);
    var dirty = engine.ensureToday(day, await _routines());
    if (change != null) {
      change(engine, day);
      dirty = true;
    }
    if (dirty) {
      final batch = scope.db.batch();
      _days.write(batch, day);
      await scope.commit(batch, offline: ctx.offline || offline);
    }
    final history = await _days.recentBefore(today);
    return engine.buildDay(day, daysAway: daysAwayFrom(today, history));
  });

  @override
  Future<Day> today() => _today();

  @override
  Future<Day> start(String stepId) => _today((e, d) => e.start(d, stepId));

  @override
  Future<Day> pause(String stepId) => _today((e, d) => e.pause(d, stepId));

  @override
  Future<Day> complete(String stepId, {double? actualValue}) =>
      _today((e, d) => e.complete(d, stepId, actualValue: actualValue));

  @override
  Future<Day> skip(String stepId, {SkipReason? reason}) =>
      _today((e, d) => e.skip(d, stepId, reason: reason?.api ?? ''));

  @override
  Future<Day> undo(String stepId) => _today((e, d) => e.reset(d, stepId));

  @override
  Future<Day> setMode(DayMode mode) => _today((e, d) => e.setDayMode(d, mode));

  @override
  Future<Day> dismissRecovery() => _today((e, d) => e.dismissRecovery(d));

  @override
  Future<void> reflect(String stepId, String note) => _today((e, d) => e.reflect(d, stepId, note));

  @override
  Future<AdaptationPreview> preview(String instanceId, {int? budgetMinutes, bool minimum = false}) =>
      guardFirebase(() async {
        final ctx = await scope.context();
        final (:day, offline: _) = await _days.load(ctx.clock.today());
        return DayEngine(ctx.clock).buildPreview(day, instanceId, budgetMinutes: budgetMinutes, minimum: minimum);
      });

  @override
  Future<Day> applyBudget(String instanceId, int minutes) =>
      _today((e, d) => e.applyTimeBudget(d, instanceId, minutes));

  @override
  Future<Day> revert(String adjustmentId) => _today((e, d) => e.revertAdjustment(d, adjustmentId));
}
