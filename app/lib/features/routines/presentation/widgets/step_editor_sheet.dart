import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/widgets/mw_button.dart';
import '../../../../core/widgets/mw_chips.dart';
import '../../../../core/widgets/mw_icons.dart';
import '../../../../core/widgets/mw_sheet.dart';
import '../../../../core/widgets/mw_toggle.dart';
import '../../../goals/application/goals_controller.dart';
import '../../domain/routine.dart';

/// Add or edit a step: what it is, how it's measured, its minimum version, essential ★, priority and habit.
Future<void> showStepEditor(
  BuildContext context, {
  required Future<void> Function(RoutineStep) onSave,
  RoutineStep? initial,
}) {
  return showMwSheet<void>(
    context,
    title: initial == null ? 'Add a step' : 'Edit step',
    builder: (_) => _StepForm(initial: initial, onSave: onSave),
  );
}

class _StepForm extends ConsumerStatefulWidget {
  const _StepForm({required this.onSave, this.initial});

  final RoutineStep? initial;
  final Future<void> Function(RoutineStep) onSave;

  @override
  ConsumerState<_StepForm> createState() => _StepFormState();
}

class _StepFormState extends ConsumerState<_StepForm> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _unit = TextEditingController(text: widget.initial?.unit);
  late String _icon = widget.initial?.icon ?? 'check_circle';
  late TargetKind _kind = widget.initial?.targetKind ?? TargetKind.duration;
  late double _target = widget.initial?.targetValue ?? 10;
  late double? _minimum = widget.initial?.minimumValue;
  late bool _essential = widget.initial?.isEssential ?? false;
  late StepPriority _priority = widget.initial?.priority ?? StepPriority.standard;
  late String? _habitId = widget.initial?.habitId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'What is this step?');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        RoutineStep(
          id: widget.initial?.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          icon: _icon,
          targetKind: _kind,
          targetValue: _kind == TargetKind.check ? 1 : _target,
          minimumValue: _kind == TargetKind.check ? null : _minimum,
          unit: _kind == TargetKind.count ? _unit.text.trim() : '',
          isEssential: _essential,
          priority: _priority,
          habitId: _habitId,
        ),
      );
      if (mounted) Navigator.pop(context);
    } on AppFailure catch (f) {
      setState(() => _error = f.userMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final habits = ref.watch(habitOptionsProvider);
    final unitLabel = _kind == TargetKind.duration ? 'min' : (_unit.text.isEmpty ? '' : _unit.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Step', hintText: 'Stretch', errorText: _error),
        ),
        const SizedBox(height: MwSpace.sm),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Note (optional)'),
        ),
        const SizedBox(height: MwSpace.md),
        Text('Icon', style: context.text.labelLarge),
        const SizedBox(height: MwSpace.xs),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final entry in stepIcons.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Semantics(
                    selected: entry.key == _icon,
                    label: entry.key.replaceAll('_', ' '),
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(MwRadii.md),
                      onTap: () => setState(() => _icon = entry.key),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: entry.key == _icon ? c.accentTint : c.sunken,
                          borderRadius: BorderRadius.circular(MwRadii.md),
                          border: entry.key == _icon ? Border.all(color: c.accent, width: 1.5) : null,
                        ),
                        child: Icon(entry.value, size: 20, color: entry.key == _icon ? c.accentText : c.textSecondary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: MwSpace.md),
        Text('Measured by', style: context.text.labelLarge),
        const SizedBox(height: MwSpace.xs),
        MwPillRow<TargetKind>(
          options: TargetKind.values,
          selected: _kind,
          labelOf: (k) => k.label,
          onSelected: (k) => setState(() {
            _kind = k;
            if (_minimum != null && _minimum! > _target) _minimum = null;
          }),
        ),
        if (_kind != TargetKind.check) ...[
          const SizedBox(height: MwSpace.md),
          if (_kind == TargetKind.count)
            TextField(
              controller: _unit,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Unit', hintText: 'pages, glasses, km'),
            ),
          _Stepper(
            label: 'Target',
            value: _target,
            unit: unitLabel,
            min: 1,
            onChanged: (v) => setState(() {
              _target = v;
              if (_minimum != null && _minimum! > v) _minimum = v;
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _minimum != null,
            onChanged: (on) => setState(() => _minimum = on ? (_target / 4).ceilToDouble().clamp(1, _target) : null),
            title: Text('Minimum version', style: context.text.labelLarge),
            subtitle: Text(
              'The smallest version that still counts. Used on busy and low-energy days.',
              style: context.text.bodySmall,
            ),
          ),
          if (_minimum != null)
            _Stepper(
              label: 'Minimum',
              value: _minimum!,
              unit: unitLabel,
              min: 1,
              max: _target,
              onChanged: (v) => setState(() => _minimum = v),
            ),
        ],
        const SizedBox(height: MwSpace.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('★ Essential', style: context.text.labelLarge),
                  Text(
                    'Stays on Minimum Days and is never dropped when time is tight.',
                    style: context.text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
            ),
            MwToggle(value: _essential, semanticLabel: 'Essential', onChanged: (v) => setState(() => _essential = v)),
          ],
        ),
        const SizedBox(height: MwSpace.md),
        Text('Priority when time is short', style: context.text.labelLarge),
        const SizedBox(height: MwSpace.xs),
        MwPillRow<StepPriority>(
          options: StepPriority.values,
          selected: _priority,
          labelOf: (p) => p.label,
          onSelected: (p) => setState(() => _priority = p),
        ),
        const SizedBox(height: MwSpace.md),
        habits.when(
          data: (options) => DropdownButtonFormField<String?>(
            initialValue: options.any((h) => h.id == _habitId) ? _habitId : null,
            decoration: const InputDecoration(labelText: 'Supports a habit (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final h in options) DropdownMenuItem(value: h.id, child: Text(h.title)),
            ],
            onChanged: (v) => setState(() => _habitId = v),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: MwSpace.lg),
        MwButton(label: widget.initial == null ? 'Add step' : 'Save step', isLoading: _saving, onPressed: _save),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.unit,
    required this.onChanged,
    this.min = 1,
    this.max = 600,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final step = value >= 30 ? 5.0 : 1.0;
    return Row(
      children: [
        Expanded(child: Text(label, style: context.text.labelLarge)),
        IconButton.filledTonal(
          tooltip: 'Less',
          onPressed: value - step >= min ? () => onChanged(value - step) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 88,
          child: Text('${value.round()} $unit'.trim(), textAlign: TextAlign.center, style: context.text.titleMedium),
        ),
        IconButton.filledTonal(
          tooltip: 'More',
          onPressed: value + step <= max ? () => onChanged(value + step) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
