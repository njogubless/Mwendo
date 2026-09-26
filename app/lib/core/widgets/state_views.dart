import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../errors/app_failure.dart';
import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import 'mw_button.dart';

/// Shared Loading / Empty / Error / Offline presentations so every screen
/// handles non-happy paths the same calm way (docs/engineering/error-handling.md).

class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        label: message ?? 'Loading',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
            if (message != null) ...[
              const SizedBox(height: MwSpace.md),
              Text(message!, style: context.text.bodyMedium?.copyWith(color: context.mwColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconBackground,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final Color? iconBackground;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MwSpace.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: iconBackground ?? c.accentTint, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor ?? c.accentText, size: 28),
              ),
              const SizedBox(height: MwSpace.md),
              Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
              if (message != null) ...[
                const SizedBox(height: MwSpace.sm),
                Text(
                  message!,
                  style: context.text.bodyMedium?.copyWith(color: c.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: MwSpace.lg),
                MwButton(label: actionLabel!, onPressed: onAction, expand: false),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({required this.title, this.message, this.icon, this.actionLabel, this.onAction, super.key});

  final String title;
  final String? message;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => MessageView(
    icon: icon ?? Symbols.spa,
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, this.onRetry, super.key});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final offline = failure is NetworkFailure;
    return MessageView(
      icon: offline ? Symbols.cloud_off : Symbols.refresh,
      iconColor: c.onGentleTint,
      iconBackground: c.gentleTint,
      title: offline ? "You're offline" : "Let's try that again",
      message: failure.userMessage,
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Thin banner shown above content when the device is offline but cached data is visible.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: MwSpace.md, vertical: MwSpace.sm),
        color: c.sunken,
        child: Row(
          children: [
            Icon(Symbols.cloud_off, size: 16, color: c.textSecondary),
            const SizedBox(width: MwSpace.sm),
            Expanded(
              child: Text(
                "You're offline. We'll sync when you're back.",
                style: context.text.labelMedium?.copyWith(color: c.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
