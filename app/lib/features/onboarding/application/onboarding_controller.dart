import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/session_controller.dart';
import '../../profile/data/profile_repository.dart';
import '../../routines/application/routines_controller.dart';
import '../../routines/data/routines_repository_impl.dart';
import '../../routines/domain/routine.dart';
import '../../today/application/today_controller.dart';

class FocusArea {
  const FocusArea(this.id, this.label, this.hint);

  final String id;
  final String label;
  final String hint;
}

const focusAreas = [
  FocusArea('health', 'Health & movement', 'Move, eat and sleep well'),
  FocusArea('mind', 'Calm mind', 'Breathe, reflect, slow down'),
  FocusArea('learning', 'Learning', 'Read, study, grow a skill'),
  FocusArea('focus', 'Focused work', 'Protect deep, meaningful work'),
  FocusArea('relationships', 'People', 'Time with those who matter'),
  FocusArea('rest', 'Rest', 'Wind down and recover'),
];

class OnboardingState {
  const OnboardingState({
    this.focus = const {},
    this.structure = 'balanced',
    this.wakeMinutes = 6 * 60 + 30,
    this.dayStartMinutes = 4 * 60,
    this.drafts,
    this.included = const {},
  });

  final Set<String> focus;
  final String structure;
  final int wakeMinutes;
  final int dayStartMinutes;
  final List<RoutineDraft>? drafts;
  final Set<int> included;

  OnboardingState copyWith({
    Set<String>? focus,
    String? structure,
    int? wakeMinutes,
    int? dayStartMinutes,
    List<RoutineDraft>? drafts,
    Set<int>? included,
    bool clearDrafts = false,
  }) => OnboardingState(
    focus: focus ?? this.focus,
    structure: structure ?? this.structure,
    wakeMinutes: wakeMinutes ?? this.wakeMinutes,
    dayStartMinutes: dayStartMinutes ?? this.dayStartMinutes,
    drafts: clearDrafts ? null : (drafts ?? this.drafts),
    included: included ?? this.included,
  );
}

/// Collects onboarding answers, asks the server for a first routine, then creates what the user keeps.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  void toggleFocus(String id) {
    final next = {...state.focus};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(focus: next, clearDrafts: true);
  }

  void setStructure(String v) => state = state.copyWith(structure: v, clearDrafts: true);

  void setWake(int minutes) => state = state.copyWith(wakeMinutes: minutes, clearDrafts: true);

  void setDayStart(int minutes) => state = state.copyWith(dayStartMinutes: minutes);

  void toggleDraft(int index) {
    final next = {...state.included};
    next.contains(index) ? next.remove(index) : next.add(index);
    state = state.copyWith(included: next);
  }

  Future<void> generate() async {
    final drafts = await ref
        .read(routinesRepositoryProvider)
        .generate(focusAreas: state.focus.toList(), structure: state.structure, wakeMinutes: state.wakeMinutes);
    state = state.copyWith(drafts: drafts, included: {for (var i = 0; i < drafts.length; i++) i});
  }

  /// For existing users ("Suggest routines for me"): creates the kept routines only.
  Future<int> addSuggested() async {
    final routines = ref.read(routinesRepositoryProvider);
    var created = 0;
    for (final (i, d) in (state.drafts ?? const <RoutineDraft>[]).indexed) {
      if (state.included.contains(i)) {
        await routines.create(d.details, steps: d.steps);
        created++;
      }
    }
    ref
      ..invalidate(routinesControllerProvider)
      ..invalidate(todayControllerProvider);
    return created;
  }

  /// Saves answers, creates the kept routines and marks onboarding complete (router then opens Today).
  Future<void> finish({bool withRoutines = true}) async {
    final profile = ref.read(profileRepositoryProvider);
    final routines = ref.read(routinesRepositoryProvider);
    await profile.savePreferences(
      focusAreas: state.focus.toList(),
      structure: state.structure,
      wakeMinutes: state.wakeMinutes,
    );
    await profile.update(dayStartMinutes: state.dayStartMinutes);
    if (withRoutines) {
      final drafts = state.drafts ?? const [];
      for (final (i, d) in drafts.indexed) {
        if (state.included.contains(i)) await routines.create(d.details, steps: d.steps);
      }
    }
    final user = await profile.completeOnboarding();
    ref.invalidate(todayControllerProvider);
    ref.read(sessionControllerProvider.notifier).updateUser(user);
  }
}

final onboardingControllerProvider = NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
  OnboardingController.new,
);
