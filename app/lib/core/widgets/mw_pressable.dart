import 'package:flutter/material.dart';

import '../theme/mw_tokens.dart';

/// Scales its child to 0.98 while pressed (design-system press feedback).
class MwPressable extends StatefulWidget {
  const MwPressable({required this.child, this.onTap, this.enabled = true, super.key});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<MwPressable> createState() => _MwPressableState();
}

class _MwPressableState extends State<MwPressable> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _set(bool value) {
    if (_active && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: _active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? MwMotion.pressScale : 1,
        duration: MwMotion.fast,
        curve: MwMotion.standard,
        child: widget.child,
      ),
    );
  }
}
