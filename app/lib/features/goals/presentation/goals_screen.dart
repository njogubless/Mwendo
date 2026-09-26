import 'package:flutter/material.dart';

import '../../../core/widgets/tab_placeholder.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) => const TabPlaceholder(
    title: 'Goals',
    emptyTitle: 'What are you moving toward?',
    emptyMessage: 'Goals connect your daily steps to the bigger picture.',
  );
}
