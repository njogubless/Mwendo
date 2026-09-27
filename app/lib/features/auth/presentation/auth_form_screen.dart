import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/mw_tokens.dart';
import '../../../core/utils/device_timezone.dart';
import '../../../core/widgets/mw_button.dart';
import '../../../core/widgets/mw_card.dart';
import '../../dev/server_settings.dart';
import '../application/session_controller.dart';

enum AuthMode { signIn, register }

class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({required this.mode, super.key});

  final AuthMode mode;

  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  AppFailure? _failure;

  bool get _isRegister => widget.mode == AuthMode.register;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _serverError(String field) => switch (_failure) {
    ValidationFailure(:final fieldErrors) => fieldErrors[field]?.join('\n'),
    _ => null,
  };

  Future<void> _submit() async {
    setState(() => _failure = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final session = ref.read(sessionControllerProvider.notifier);
    try {
      if (_isRegister) {
        await session.register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
          timezone: await ref.read(deviceTimezoneProvider.future),
        );
      } else {
        await session.signIn(email: _email.text.trim(), password: _password.text);
      }
      // Router redirect takes over once the session is SignedIn.
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final generalMessage = switch (_failure) {
      null => null,
      ValidationFailure(:final fieldErrors) when fieldErrors.keys.any({'email', 'password', 'display_name'}.contains) =>
        null,
      final failure => failure.userMessage,
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.welcome),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MwSpace.marginCompact),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_isRegister ? "Let's begin" : 'Welcome back', style: context.text.headlineMedium),
                      const SizedBox(height: MwSpace.sm),
                      Text(
                        _isRegister
                            ? 'Create your account. It takes less than a minute.'
                            : 'Sign in to pick up where you left off.',
                        style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                      ),
                      const SizedBox(height: MwSpace.lg),
                      if (_isRegister) ...[
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.givenName],
                          decoration: InputDecoration(
                            labelText: 'What should we call you?',
                            errorText: _serverError('display_name'),
                          ),
                        ),
                        const SizedBox(height: MwSpace.md),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: InputDecoration(labelText: 'Email', errorText: _serverError('email')),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          if (value.isEmpty) return 'Please enter your email.';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                            return 'That email doesn’t look quite right.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: MwSpace.md),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        autofillHints: [_isRegister ? AutofillHints.newPassword : AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          helperText: _isRegister ? 'At least 8 characters.' : null,
                          errorText: _serverError('password'),
                          errorMaxLines: 3,
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').isEmpty) return 'Please enter your password.';
                          if (_isRegister && v!.length < 8) return 'Use at least 8 characters.';
                          return null;
                        },
                      ),
                      if (generalMessage != null) ...[
                        const SizedBox(height: MwSpace.md),
                        MwCard(
                          tone: MwCardTone.sunken,
                          padding: const EdgeInsets.all(MwSpace.md),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(generalMessage, style: context.text.bodySmall),
                          ),
                        ),
                      ],
                      const SizedBox(height: MwSpace.lg),
                      MwButton(
                        label: _isRegister ? 'Create account' : 'Sign in',
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                      if (!_isRegister)
                        MwButton(
                          label: 'Forgot password?',
                          variant: MwButtonVariant.text,
                          onPressed: () => context.push(Routes.forgotPassword),
                        ),
                      const SizedBox(height: MwSpace.sm),
                      MwButton(
                        label: _isRegister ? 'I already have an account' : 'Create an account instead',
                        variant: MwButtonVariant.text,
                        onPressed: () => context.pushReplacement(_isRegister ? Routes.signIn : Routes.register),
                      ),
                      const ServerHint(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
