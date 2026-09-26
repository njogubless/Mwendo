import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_theme.dart';
import '../theme/mw_tokens.dart';
import '../widgets/brand_mark.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Order must match the branches in `app_router.dart`.
const shellDestinations = [
  ShellDestination('Today', Symbols.radio_button_checked),
  ShellDestination('Routines', Symbols.view_timeline),
  ShellDestination('Goals', Symbols.flag),
  ShellDestination('Insights', Symbols.insights),
  ShellDestination('Profile', Symbols.account_circle),
];

/// Primary navigation that adapts to width: floating dock (compact),
/// navigation rail (medium), calm sidebar (expanded).
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final index = navigationShell.currentIndex;

    if (width < MwBreakpoints.medium) {
      return Scaffold(
        extendBody: true,
        body: navigationShell,
        bottomNavigationBar: MwBottomDock(currentIndex: index, onSelect: _select),
      );
    }

    final side = width < MwBreakpoints.expanded
        ? _Rail(currentIndex: index, onSelect: _select)
        : _Sidebar(currentIndex: index, onSelect: _select);
    return Scaffold(
      body: Row(
        children: [
          side,
          VerticalDivider(width: 1, color: context.mwColors.hairline),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

class MwBottomDock extends StatelessWidget {
  const MwBottomDock({required this.currentIndex, required this.onSelect, super.key});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: MwSpace.md),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MwSpace.marginCompact),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MwRadii.dock),
                boxShadow: MwShadows.floating(c.shadow),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MwRadii.dock),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    height: 64,
                    color: c.surface.withValues(alpha: 0.88),
                    padding: const EdgeInsets.symmetric(horizontal: MwSpace.xs),
                    child: Row(
                      children: [
                        for (var i = 0; i < shellDestinations.length; i++)
                          Expanded(
                            child: _DockItem(
                              destination: shellDestinations[i],
                              selected: i == currentIndex,
                              onTap: () => onSelect(i),
                            ),
                          ),
                      ],
                    ),
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

class _DockItem extends StatelessWidget {
  const _DockItem({required this.destination, required this.selected, required this.onTap});

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    final color = selected ? c.accentText : c.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(destination.icon, size: 22, color: color, fill: selected ? 1 : 0),
            const SizedBox(height: 2),
            Text(
              destination.label,
              style: context.text.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: MwMotion.medium,
              curve: MwMotion.standard,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(color: c.action, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: onSelect,
      labelType: NavigationRailLabelType.all,
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: MwSpace.md),
        child: BrandMark(size: 32),
      ),
      destinations: [
        for (final d in shellDestinations)
          NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.icon, fill: 1), label: Text(d.label)),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.mwColors;
    return SafeArea(
      child: SizedBox(
        width: 240,
        child: Padding(
          padding: const EdgeInsets.all(MwSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLockup(),
              const SizedBox(height: MwSpace.xl),
              for (var i = 0; i < shellDestinations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: MwSpace.xs),
                  child: Material(
                    color: i == currentIndex ? c.accentTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(MwRadii.lg),
                    child: ListTile(
                      selected: i == currentIndex,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MwRadii.lg)),
                      leading: Icon(
                        shellDestinations[i].icon,
                        fill: i == currentIndex ? 1 : 0,
                        color: i == currentIndex ? c.accentText : c.textSecondary,
                      ),
                      title: Text(
                        shellDestinations[i].label,
                        style: context.text.labelLarge?.copyWith(
                          color: i == currentIndex ? c.accentText : c.textSecondary,
                        ),
                      ),
                      onTap: () => onSelect(i),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
