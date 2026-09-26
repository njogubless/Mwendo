import 'package:flutter/material.dart';

import '../../../core/widgets/tab_placeholder.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) => const TabPlaceholder(
    title: 'Insights',
    emptyTitle: 'Building your rhythm',
    emptyMessage: 'After a few days, Mwendo will show what helps you keep moving.',
  );
}
