import 'routine.dart';

/// Deterministic first-routine generator used by onboarding (port of backend `routines/generator.py`).
///
/// Given focus areas, a structure preference and a wake time it proposes 1–3 routines with sensible steps,
/// minimum versions and essentials. It never saves anything: the user reviews, edits and then creates.
const generatorFocusAreas = ['health', 'mind', 'learning', 'focus', 'relationships', 'rest'];
const _weekdays = [1, 2, 3, 4, 5];
const _everyDay = [1, 2, 3, 4, 5, 6, 7];

RoutineStep _step(
  String title,
  String icon, {
  int? minutes,
  int? minimum,
  bool essential = false,
  StepPriority priority = StepPriority.standard,
  TargetKind? kind,
  String unit = '',
  String description = '',
}) {
  final k = kind ?? (minutes != null ? TargetKind.duration : TargetKind.check);
  return RoutineStep(
    title: title,
    description: description,
    icon: icon,
    targetKind: k,
    targetValue: k == TargetKind.check ? 1 : minutes!.toDouble(),
    minimumValue: k == TargetKind.check ? null : minimum?.toDouble(),
    unit: unit,
    isEssential: essential,
    priority: priority,
  );
}

List<RoutineDraft> generateRoutines({required List<String> focusAreas, required String structure, int? wakeMinutes}) {
  final chosen = focusAreas.where(generatorFocusAreas.contains).toList();
  final areas = chosen.isEmpty ? ['health', 'mind'] : chosen;
  final wake = wakeMinutes ?? 6 * 60 + 30;
  final loose = structure == 'loose';
  final structured = structure == 'structured';

  final morning = [
    _step('Drink a glass of water', 'water_drop', essential: true, priority: StepPriority.core),
    if (areas.contains('health'))
      _step(
        'Move your body',
        'directions_run',
        minutes: 20,
        minimum: 5,
        essential: true,
        priority: StepPriority.core,
        description: 'A walk, stretch or workout — any movement counts.',
      ),
    if (areas.contains('mind') || loose)
      _step(
        'Breathe and settle',
        'self_improvement',
        minutes: 5,
        minimum: 2,
        essential: !areas.contains('health'),
        priority: areas.contains('health') ? StepPriority.standard : StepPriority.core,
      ),
    if (areas.contains('learning') && !loose)
      _step('Read', 'menu_book', minutes: 15, minimum: 5, priority: StepPriority.optional),
    if (!loose)
      _step(
        'Plan your day',
        'edit_note',
        minutes: 5,
        minimum: 2,
        description: 'Pick the one thing that matters most today.',
      ),
    if (structured)
      _step('Nourishing breakfast', 'restaurant', minutes: 20, minimum: 10, priority: StepPriority.optional),
  ];
  final morningMinutes = morning.where((s) => s.isTimed).fold(0, (total, s) => total + s.targetValue.round());

  final routines = [
    RoutineDraft(
      details: RoutineDetails(
        name: 'Morning',
        category: RoutineCategory.morning,
        description: 'Start the day grounded.',
        daysOfWeek: _everyDay,
        startMinutes: (wake + 10) % 1440,
        finishByMinutes: structured ? (wake + 10 + morningMinutes + 30) % 1440 : null,
      ),
      steps: _positioned(morning),
    ),
  ];

  if ((areas.contains('focus') || areas.contains('learning')) && !loose) {
    routines.add(
      RoutineDraft(
        details: const RoutineDetails(
          name: 'Focus block',
          category: RoutineCategory.work,
          description: 'Protected time for what matters.',
          daysOfWeek: _weekdays,
          startMinutes: 9 * 60,
        ),
        steps: _positioned([
          _step(
            'Set one clear intention',
            'flag',
            minutes: 2,
            minimum: 1,
            essential: true,
            priority: StepPriority.core,
          ),
          _step(
            'Deep work',
            'psychology',
            minutes: structured ? 90 : 60,
            minimum: 25,
            essential: true,
            priority: StepPriority.core,
          ),
          _step('Short reset', 'local_cafe', minutes: 10, minimum: 5, priority: StepPriority.optional),
        ]),
      ),
    );
  }

  final evening = [
    _step('Reflect on today', 'edit_note', minutes: 5, minimum: 2, essential: true, priority: StepPriority.core),
    if (areas.contains('relationships'))
      _step(
        'Connect with someone',
        'favorite',
        minutes: 15,
        minimum: 5,
        description: 'A call, a message or time together.',
      ),
    if (areas.contains('learning'))
      _step('Read', 'menu_book', minutes: 20, minimum: 5, kind: TargetKind.count, unit: 'pages'),
    if (areas.contains('rest') || structured) _step('Screens off', 'bedtime', essential: areas.contains('rest')),
    _step('Gratitude', 'spa', minutes: 3, minimum: 1, priority: StepPriority.optional),
  ];
  routines.add(
    RoutineDraft(
      details: const RoutineDetails(
        name: 'Evening wind-down',
        category: RoutineCategory.evening,
        description: 'Close the day gently.',
        daysOfWeek: _everyDay,
        startMinutes: 21 * 60,
      ),
      steps: _positioned(evening),
    ),
  );
  return routines;
}

List<RoutineStep> _positioned(List<RoutineStep> steps) => [
  for (final (i, s) in steps.indexed)
    RoutineStep(
      title: s.title,
      position: i,
      description: s.description,
      icon: s.icon,
      targetKind: s.targetKind,
      targetValue: s.targetValue,
      minimumValue: s.minimumValue,
      unit: s.unit,
      isEssential: s.isEssential,
      priority: s.priority,
    ),
];
