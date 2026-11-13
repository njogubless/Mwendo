import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/widgets/mw_button.dart';
import '../application/session_controller.dart';
import '../data/auth_repository_impl.dart';

/// Django: two steps, email → 6-digit code + new password, then signs in (D-019).
/// Firebase: email → a reset link opens Firebase's page; the user then signs in (D-031).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _field(String name) => switch (_failure) {
    ValidationFailure(:final fieldErrors) => fieldErrors[name]?.join('\n'),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final byLink = ref.watch(passwordResetMethodProvider) == PasswordResetMethod.link;
    final general = switch (_failure) {
      ValidationFailure(:final fieldErrors) when fieldErrors.isNotEmpty => null,
      final f? => f.userMessage,
      null => null,
    };
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.signIn),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MwSpace.marginCompact),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_codeSent ? 'Check your email' : 'Reset your password', style: context.text.headlineMedium),
                  const SizedBox(height: MwSpace.sm),
                  Text(switch ((_codeSent, byLink)) {
                    (true, true) =>
                      'If ${_email.text.trim()} has an account, a reset link is on its way. Open it to choose a '
                          'new password, then sign in here.',
                    (true, false) =>
                      'If ${_email.text.trim()} has an account, a 6-digit code is on its way. It works for 15 minutes.',
                    (false, true) => "Enter your email and we'll send you a link to reset your password.",
                    (false, false) => "Enter your email and we'll send you a code.",
                  }, style: context.text.bodyMedium?.copyWith(color: c.textSecondary)),
                  const SizedBox(height: MwSpace.lg),
                  TextField(
                    controller: _email,
                    enabled: !_codeSent,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: 'Email', errorText: _field('email')),
                  ),
                  if (_codeSent && !byLink) ...[
                    const SizedBox(height: MwSpace.md),
                    TextField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      maxLength: 6,
                      decoration: InputDecoration(labelText: '6-digit code', errorText: _field('code')),
                    ),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 8 characters.',
                        errorText: _field('new_password'),
                        errorMaxLines: 3,
                      ),
                    ),
                  ],
                  if (general != null) ...[
                    const SizedBox(height: MwSpace.md),
                    Semantics(liveRegion: true, child: Text(general, style: context.text.bodySmall)),
                  ],
                  const SizedBox(height: MwSpace.lg),
                  if (!_codeSent)
                    MwButton(
                      label: byLink ? 'Send link' : 'Send code',
                      isLoading: _busy,
                      onPressed: () => _guard(() async {
                        await ref.read(authRepositoryProvider).requestPasswordReset(_email.text.trim());
                        setState(() => _codeSent = true);
                      }),
                    )
                  else if (byLink) ...[
                    MwButton(label: 'Back to sign in', onPressed: () => context.go(Routes.signIn)),
                    MwButton(
                      label: 'Send the link again',
                      variant: MwButtonVariant.text,
                      onPressed: _busy
                          ? null
                          : () =>
                                _guard(() => ref.read(authRepositoryProvider).requestPasswordReset(_email.text.trim())),
                    ),
                  ] else ...[
                    MwButton(
                      label: 'Set new password',
                      isLoading: _busy,
                      onPressed: () => _guard(
                        () => ref
                            .read(sessionControllerProvider.notifier)
                            .resetPassword(
                              email: _email.text.trim(),
                              code: _code.text.trim(),
                              newPassword: _password.text,
                            ),
                      ),
                    ),
                    MwButton(
                      label: 'Send a new code',
                      variant: MwButtonVariant.text,
                      onPressed: _busy
                          ? null
                          : () =>
                                _guard(() => ref.read(authRepositoryProvider).requestPasswordReset(_email.text.trim())),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
