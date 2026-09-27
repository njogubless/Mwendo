import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/mw_tokens.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../core/widgets/mw_button.dart';
import '../../../../core/widgets/mw_chips.dart';
import '../../../../core/widgets/mw_sheet.dart';
import '../../domain/routine.dart';

/// Create or edit a routine's name, category and schedule. Calls [onSave]; shows its failure inline.
Future<void> showRoutineDetailsSheet(
  BuildContext context, {
  required Future<void> Function(RoutineDetails) onSave,
  RoutineDetails? initial,
}) {
  return showMwSheet<void>(
    context,
    title: initial == null ? 'New routine' : 'Routine details',
    builder: (_) => _RoutineDetailsForm(initial: initial, onSave: onSave),
  );
}

class _RoutineDetailsForm extends StatefulWidget {
  const _RoutineDetailsForm({required this.onSave, this.initial});

  final RoutineDetails? initial;
  final Future<void> Function(RoutineDetails) onSave;

  @override
  State<_RoutineDetailsForm> createState() => _RoutineDetailsFormState();
}

class _RoutineDetailsFormState extends State<_RoutineDetailsForm> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late RoutineCategory _category = widget.initial?.category ?? RoutineCategory.morning;
  late final Set<int> _days = {
    ...?widget.initial?.daysOfWeek.toSet(),
    if (widget.initial == null) ...[1, 2, 3, 4, 5, 6, 7],
  };
  late int? _start = widget.initial?.startMinutes ?? (widget.initial == null ? 7 * 60 : null);
  late int? _finishBy = widget.initial?.finishByMinutes;
  bool _saving = false;
  String? _error;

  /// "Be done by" must come after "Starts at" (a morning routine can't finish before it begins).
  bool get _finishTooEarly => _start != null && _finishBy != null && _finishBy! <= _start!;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<int?> _pickTime(int? current, int fallback) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (current ?? fallback) ~/ 60, minute: (current ?? fallback) % 60),
    );
    return t == null ? null : t.hour * 60 + t.minute;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your routine a name.');
      return;
    }
    if (_finishTooEarly) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        RoutineDetails(
          name: name,
          category: _category,
          daysOfWeek: _days.toList()..sort(),
          startMinutes: _start,
          finishByMinutes: _finishBy,
          description: widget.initial?.description ?? '',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: widget.initial == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Name', hintText: 'Morning', errorText: _error),
        ),
        const SizedBox(height: MwSpace.md),
        Text('Kind', style: context.text.labelLarge),
        const SizedBox(height: MwSpace.xs),
        MwPillRow<RoutineCategory>(
          options: RoutineCategory.values,
          selected: _category,
          labelOf: (c) => c.label,
          onSelected: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: MwSpace.md),
        Text('Days', style: context.text.labelLarge),
        const SizedBox(height: MwSpace.xs),
        Wrap(
          spacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              MwChoicePill(
                label: weekdayShort[d - 1],
                selected: _days.contains(d),
                onTap: () => setState(() => _days.contains(d) ? _days.remove(d) : _days.add(d)),
              ),
          ],
        ),
        Text(
          _days.isEmpty ? 'Not scheduled — you can still start it any time.' : formatDays(_days.toList()),
          style: context.text.bodySmall?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: MwSpace.md),
        _TimeRow(
          label: 'Starts at',
          value: _start == null ? 'Any time' : formatClock(context, _start!),
          onTap: () async {
            final t = await _pickTime(_start, 7 * 60);
            if (t != null) setState(() => _start = t);
          },
          onClear: _start == null ? null : () => setState(() => _start = null),
        ),
        _TimeRow(
          label: 'Be done by (optional)',
          value: _finishBy == null ? 'No limit' : formatClock(context, _finishBy!),
          hint: _finishTooEarly
              ? 'Choose a time after ${formatClock(context, _start!)}.'
              : 'Used to fit the routine in when you run late.',
          hintIsError: _finishTooEarly,
          onTap: () async {
            final t = await _pickTime(_finishBy, (_start ?? 7 * 60) + 60);
            if (t != null) setState(() => _finishBy = t);
          },
          onClear: _finishBy == null ? null : () => setState(() => _finishBy = null),
        ),
        const SizedBox(height: MwSpace.lg),
        MwButton(
          label: widget.initial == null ? 'Create routine' : 'Save',
          isLoading: _saving,
          onPressed: _finishTooEarly ? null : _save,
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.hint,
    this.hintIsError = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool hintIsError;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: context.text.labelLarge),
      subtitle: hint == null
          ? null
          : Text(
              hint!,
              style: context.text.bodySmall?.copyWith(color: hintIsError ? context.mwColors.onGentleTint : null),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(onPressed: onTap, child: Text(value)),
          if (onClear != null)
            IconButton(tooltip: 'Clear', onPressed: onClear, icon: const Icon(Icons.close, size: 18)),
        ],
      ),
    );
  }
}
