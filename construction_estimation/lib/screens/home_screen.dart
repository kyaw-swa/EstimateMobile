import 'package:flutter/material.dart';

import 'abstract_of_cost/ac_list_screen.dart';
import 'dashboard_screen.dart';
import 'labour/labour_list_screen.dart';
import 'materials/material_list_screen.dart';
import 'project_estimates/estimate_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Switch from bottom-bar to side-rail above this width.
  static const double _railBreakpoint = 640;

  int _index = 0; // default tab: Dashboard

  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();

  static const _destinations = [
    _Destination(
      label: 'Home',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _Destination(
      label: 'Materials',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _Destination(
      label: 'Labour',
      icon: Icons.engineering_outlined,
      selectedIcon: Icons.engineering,
    ),
    _Destination(
      label: 'AC',
      icon: Icons.calculate_outlined,
      selectedIcon: Icons.calculate,
    ),
    _Destination(
      label: 'Estimates',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description,
    ),
  ];

  late final List<Widget> _screens = [
    DashboardScreen(key: _dashboardKey, onNavigate: _setIndex),
    const MaterialListScreen(),
    const LabourListScreen(),
    const AcListScreen(),
    const EstimateListScreen(),
  ];

  void _setIndex(int i) {
    setState(() => _index = i);
    // Returning to the dashboard after editing data elsewhere — refresh KPIs
    // and recent list so the snapshot stays current.
    if (i == 0) {
      _dashboardKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= _railBreakpoint;
        // On non-Home tabs, intercept the system back button: switch back to
        // Home instead of letting the app exit. On Home tab, let the pop
        // proceed so the OS handles app exit normally.
        return PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _setIndex(0);
          },
          child: Scaffold(
            body: useRail ? _buildWide() : _buildNarrow(),
            bottomNavigationBar: useRail
                ? null
                : NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _setIndex,
                    destinations: [
                      for (final d in _destinations)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildNarrow() => IndexedStack(index: _index, children: _screens);

  Widget _buildWide() {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _index,
          onDestinationSelected: _setIndex,
          destinations: [
            for (final d in _destinations)
              NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(d.label),
              ),
          ],
        ),
        VerticalDivider(width: 1, color: scheme.outlineVariant),
        Expanded(child: IndexedStack(index: _index, children: _screens)),
      ],
    );
  }
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
