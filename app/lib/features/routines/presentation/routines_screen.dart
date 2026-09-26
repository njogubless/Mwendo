import 'package:flutter/material.dart';

import '../../../core/widgets/tab_placeholder.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) => const TabPlaceholder(
    title: 'Routines',
    emptyTitle: 'Start small',
    emptyMessage: 'Your routines will live here — shaped around your day, not a rigid checklist.',
  );
}
