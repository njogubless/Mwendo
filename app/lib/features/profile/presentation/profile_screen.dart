import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../../core/widgets/mw_page.dart';
import '../../../core/widgets/mw_sheet.dart';
import '../../../core/widgets/section_label.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/user.dart';
import '../../reminders/presentation/reminders_settings_section.dart';
import '../../today/application/today_controller.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final user = session is SignedIn ? session.user : null;
    final c = context.mwColors;
    final repo = ref.read(profileRepositoryProvider);

    Future<void> update(Future<User> Function() call, String success) async {
      try {
        final updated = await call();
        ref.read(sessionControllerProvider.notifier).updateUser(updated);
        ref.invalidate(todayControllerProvider);
        if (context.mounted) showMwSnack(context, success);
      } on AppFailure catch (f) {
        if (context.mounted) showMwSnack(context, f.userMessage);
      }
    }

    if (user == null) return const SizedBox.shrink();
    final dayStart = user.dayStartTime.inMinutes;

    return MwPage(
      children: [
        const MwPageHeader(leading: BrandLockup(title: 'Profile')),
        MwCard(
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: c.accentTint,
                child: Text(
                  user.greetingName.characters.first.toUpperCase(),
                  style: context.text.headlineSmall?.copyWith(color: c.accentText),
                ),
              ),
              const SizedBox(width: MwSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.greetingName, style: context.text.titleLarge),
                    Text(user.email, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SectionLabel('Your day'),
        MwCard(
          padding: const EdgeInsets.symmetric(vertical: MwSpace.xs),
          child: Column(
            children: [
              _SettingTile(
                icon: Symbols.badge,
                title: 'Name',
                value: user.displayName.isEmpty ? 'Add your name' : user.displayName,
                onTap: () async {
                  final name = await _askText(context, 'What should we call you?', user.displayName);
                  if (name != null) await update(() => repo.update(displayName: name), 'Saved.');
                },
              ),
              _SettingTile(
                icon: Symbols.public,
                title: 'Time zone',
                value: user.timezone,
                onTap: () async {
                  final zone = await _pickTimezone(context, user.timezone);
                  if (zone != null) await update(() => repo.update(timezone: zone), 'Time zone updated.');
                },
              ),
              _SettingTile(
                icon: Symbols.bedtime,
                title: 'A new day starts at',
                value: formatClock(context, dayStart),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: dayStart ~/ 60, minute: dayStart % 60),
                  );
                  if (t != null) {
                    await update(() => repo.update(dayStartMinutes: t.hour * 60 + t.minute), 'Saved.');
                  }
                },
              ),
            ],
          ),
        ),
        const RemindersSettingsSection(),
        const SectionLabel('Account'),
        MwCard(
          padding: const EdgeInsets.symmetric(vertical: MwSpace.xs),
          child: Column(
            children: [
              _SettingTile(
                icon: Symbols.lock,
                title: 'Change password',
                onTap: () =>
                    showMwSheet<void>(context, title: 'Change password', builder: (_) => const _PasswordForm()),
              ),
              _SettingTile(
                icon: Symbols.delete_forever,
                title: 'Delete account',
                danger: true,
                onTap: () =>
                    showMwSheet<void>(context, title: 'Delete your account?', builder: (_) => const _DeleteForm()),
              ),
            ],
          ),
        ),
        MwButton(
          label: 'Sign out',
          icon: Symbols.logout,
          variant: MwButtonVariant.secondary,
          onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
        ),
        Center(
          child: Text(
            'Mwendo · Find your rhythm. Move forward.',
            style: context.text.labelSmall?.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }

  static Future<String?> _askText(BuildContext context, String title, String initial) {
    final controller = TextEditingController(text: initial);
    return showMwSheet<String>(
      context,
      title: title,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(controller: controller, autofocus: true, textCapitalization: TextCapitalization.words),
          const SizedBox(height: MwSpace.md),
          MwButton(label: 'Save', onPressed: () => Navigator.pop(context, controller.text.trim())),
        ],
      ),
    );
  }

  static Future<String?> _pickTimezone(BuildContext context, String current) async {
    List<String> zones;
    try {
      zones = (await FlutterTimezone.getAvailableTimezones()).map((z) => z.identifier).toList()..sort();
    } on Object {
      zones = const ['UTC', 'Africa/Nairobi', 'Africa/Lagos', 'Europe/London', 'America/New_York', 'Asia/Kolkata'];
    }
    if (!context.mounted) return null;
    return showMwSheet<String>(
      context,
      title: 'Time zone',
      builder: (_) => _ZonePicker(zones: zones, current: current),
    );
  }
}

class _ZonePicker extends StatefulWidget {
  const _ZonePicker({required this.zones, required this.current});

  final List<String> zones;
  final String current;

  @override
  State<_ZonePicker> createState() => _ZonePickerState();
}

class _ZonePickerState extends State<_ZonePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final matches = widget.zones.where((z) => z.toLowerCase().contains(_query.toLowerCase())).take(60).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          autofocus: true,
          decoration: const InputDecoration(prefixIcon: Icon(Symbols.search), hintText: 'Search, e.g. Nairobi'),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: MwSpace.sm),
        SizedBox(
          height: 320,
          child: ListView(
            children: [
              for (final z in matches)
                ListTile(
                  title: Text(z),
                  trailing: z == widget.current ? const Icon(Symbols.check) : null,
                  onTap: () => Navigator.pop(context, z),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.icon, required this.title, required this.onTap, this.value, this.danger = false});

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return ListTile(
      leading: Icon(icon, color: danger ? c.danger : c.textSecondary),
      title: Text(title, style: context.text.labelLarge?.copyWith(color: danger ? c.danger : null)),
      subtitle: value == null ? null : Text(value!, style: context.text.bodySmall),
      trailing: Icon(Symbols.chevron_right, color: c.textTertiary),
      onTap: onTap,
    );
  }
}

class _PasswordForm extends ConsumerStatefulWidget {
  const _PasswordForm();

  @override
  ConsumerState<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends ConsumerState<_PasswordForm> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  ValidationFailure? _fields;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _fields = null;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).changePassword(current: _current.text, next: _next.text);
      if (mounted) {
        Navigator.pop(context);
        showMwSnack(context, 'Password updated.');
      }
    } on ValidationFailure catch (f) {
      setState(() => _fields = f);
    } on AppFailure catch (f) {
      setState(() => _error = f.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Current password',
            errorText: _fields?.firstErrorFor('current_password'),
          ),
        ),
        const SizedBox(height: MwSpace.sm),
        TextField(
          controller: _next,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(
            labelText: 'New password',
            helperText: 'At least 8 characters.',
            errorText: _fields?.fieldErrors['new_password']?.join('\n'),
            errorMaxLines: 3,
          ),
        ),
        if (_error != null) Text(_error!, style: context.text.bodySmall),
        const SizedBox(height: MwSpace.lg),
        MwButton(label: 'Update password', isLoading: _busy, onPressed: _save),
      ],
    );
  }
}

class _DeleteForm extends ConsumerStatefulWidget {
  const _DeleteForm();

  @override
  ConsumerState<_DeleteForm> createState() => _DeleteFormState();
}

class _DeleteFormState extends ConsumerState<_DeleteForm> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(profileRepositoryProvider).deleteAccount(_password.text);
      if (!mounted) return;
      Navigator.pop(context);
      await ref.read(sessionControllerProvider.notifier).signOut();
    } on ValidationFailure catch (f) {
      setState(() => _error = f.firstErrorFor('password') ?? f.userMessage);
    } on AppFailure catch (f) {
      setState(() => _error = f.userMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This permanently removes your routines, goals and history. It can’t be undone.',
          style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: MwSpace.md),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Your password', errorText: _error),
        ),
        const SizedBox(height: MwSpace.lg),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: c.danger,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MwRadii.lg)),
          ),
          onPressed: _busy ? null : _delete,
          child: Text(_busy ? 'Deleting…' : 'Delete my account'),
        ),
      ],
    );
  }
}
