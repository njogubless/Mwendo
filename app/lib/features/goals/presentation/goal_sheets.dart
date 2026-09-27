import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_chips.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../domain/goal.dart';

/// Shared "save, show failure inline" behaviour for goal forms.
mixin _Saving<T extends StatefulWidget> on State<T> {
  bool saving = false;
  String? error;

  Future<void> save(Future<void> Function() action) async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } on AppFailure catch (f) {
      if (mounted) setState(() => error = f.userMessage);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

Future<void> showGoalEditor(
  BuildContext context, {
  required Future<void> Function(GoalDraft) onSave,
  GoalDraft? initial,
}) => showMwSheet<void>(
  context,
  title: initial == null ? 'New goal' : 'Edit goal',
  builder: (_) => _GoalForm(initial: initial, onSave: onSave),
);

class _GoalForm extends StatefulWidget {
  const _GoalForm({required this.onSave, this.initial});

  final GoalDraft? initial;
  final Future<void> Function(GoalDraft) onSave;

  @override
  State<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends State<_GoalForm> with _Saving {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _description = TextEditingController(text: widget.initial?.description);
  late final _target = TextEditingController(
    text: widget.initial?.targetValue == null ? '' : widget.initial!.targetValue!.toStringAsFixed(0),
  );
  late final _unit = TextEditingController(text: widget.initial?.unit);
  late DateTime? _date = widget.initial?.targetDate;
  String? _titleError;

  @override
  void dispose() {
    for (final c in [_title, _description, _target, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'What are you moving toward?',
            hintText: 'Read 12 books this year',
            errorText: _titleError,
          ),
        ),
        const SizedBox(height: MwSpace.sm),
        TextField(
          controller: _description,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Why it matters (optional)'),
        ),
        const SizedBox(height: MwSpace.md),
        Text('Measure it (optional)', style: context.text.labelLarge),
        const SizedBox(height: MwSpace.xs),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _target,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Target', hintText: '12'),
              ),
            ),
            const SizedBox(width: MwSpace.sm),
            Expanded(
              child: TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unit', hintText: 'books'),
              ),
            ),
          ],
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Target date', style: context.text.labelLarge),
          trailing: TextButton(
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime(now.year, 12, 31),
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 10),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: Text(_date == null ? 'None' : MaterialLocalizations.of(context).formatMediumDate(_date!)),
          ),
        ),
        if (error != null) Text(error!, style: context.text.bodySmall?.copyWith(color: context.mwColors.onGentleTint)),
        const SizedBox(height: MwSpace.md),
        MwButton(
          label: widget.initial == null ? 'Create goal' : 'Save',
          isLoading: saving,
          onPressed: () {
            if (_title.text.trim().isEmpty) {
              setState(() => _titleError = 'Name your goal.');
              return;
            }
            final target = double.tryParse(_target.text.replaceAll(',', '.'));
            save(
              () => widget.onSave(
                GoalDraft(
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  targetValue: target != null && target > 0 ? target : null,
                  unit: _unit.text.trim(),
                  targetDate: _date,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> showLogProgressSheet(
  BuildContext context, {
  required String unit,
  required Future<void> Function(double value, DateTime on, String note) onSave,
}) => showMwSheet<void>(
  context,
  title: 'Log progress',
  builder: (_) => _LogForm(unit: unit, onSave: onSave),
);

class _LogForm extends StatefulWidget {
  const _LogForm({required this.unit, required this.onSave});

  final String unit;
  final Future<void> Function(double, DateTime, String) onSave;

  @override
  State<_LogForm> createState() => _LogFormState();
}

class _LogFormState extends State<_LogForm> with _Saving {
  final _value = TextEditingController(text: '1');
  final _note = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _value,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: InputDecoration(labelText: 'Amount', suffixText: widget.unit, errorText: error),
        ),
        const SizedBox(height: MwSpace.sm),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Finished book 4'),
        ),
        const SizedBox(height: MwSpace.lg),
        MwButton(
          label: 'Log it',
          isLoading: saving,
          onPressed: () {
            final v = double.tryParse(_value.text.replaceAll(',', '.'));
            if (v == null || v == 0) {
              setState(() => error = 'Enter an amount.');
              return;
            }
            save(() => widget.onSave(v, DateTime.now(), _note.text.trim()));
          },
        ),
      ],
    );
  }
}

Future<void> showAddHabitSheet(
  BuildContext context, {
  required Future<void> Function(String title, bool perWeek, int times) onSave,
}) => showMwSheet<void>(
  context,
  title: 'Add a habit',
  builder: (_) => _HabitForm(onSave: onSave),
);

class _HabitForm extends StatefulWidget {
  const _HabitForm({required this.onSave});

  final Future<void> Function(String, bool, int) onSave;

  @override
  State<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends State<_HabitForm> with _Saving {
  final _title = TextEditingController();
  bool _perWeek = false;
  int _times = 3;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'A habit is the repeated action behind a goal. Link it to a step in a routine and Mwendo tracks it for you.',
          style: context.text.bodySmall?.copyWith(color: context.mwColors.textSecondary),
        ),
        const SizedBox(height: MwSpace.md),
        TextField(
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Habit', hintText: 'Read 20 pages', errorText: error),
        ),
        const SizedBox(height: MwSpace.md),
        MwPillRow<bool>(
          options: const [false, true],
          selected: _perWeek,
          labelOf: (w) => w ? 'Some days a week' : 'Every day',
          onSelected: (v) => setState(() => _perWeek = v),
        ),
        if (_perWeek)
          Row(
            children: [
              Expanded(child: Text('Times a week', style: context.text.labelLarge)),
              IconButton.filledTonal(
                tooltip: 'Fewer',
                onPressed: _times > 1 ? () => setState(() => _times--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 40,
                child: Text('$_times', textAlign: TextAlign.center, style: context.text.titleMedium),
              ),
              IconButton.filledTonal(
                tooltip: 'More',
                onPressed: _times < 7 ? () => setState(() => _times++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        const SizedBox(height: MwSpace.lg),
        MwButton(
          label: 'Add habit',
          isLoading: saving,
          onPressed: () {
            if (_title.text.trim().isEmpty) {
              setState(() => error = 'Name the habit.');
              return;
            }
            save(() => widget.onSave(_title.text.trim(), _perWeek, _perWeek ? _times : 1));
          },
        ),
      ],
    );
  }
}
