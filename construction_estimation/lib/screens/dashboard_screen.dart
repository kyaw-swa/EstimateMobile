import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/project_estimate.dart';
import '../repositories/labour_repository.dart';
import '../repositories/material_repository.dart';
import '../repositories/project_estimate_repository.dart';
import '../services/backup_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/numeric_field.dart';
import '../widgets/rich_list_card.dart';
import '../widgets/sliver_hero_app_bar.dart';
import 'project_estimates/estimate_form_screen.dart';
import 'settings_screen.dart';

/// Dashboard — entry screen with live KPIs, recent estimates, quick actions.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// Tab-switch callback wired by HomeScreen — index follows _destinations order
  /// (1 = Materials, 2 = Labour, 3 = AC, 4 = Estimates).
  final void Function(int tabIndex)? onNavigate;

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _estimateRepo = ProjectEstimateRepository();
  final _materialRepo = MaterialRepository();
  final _labourRepo = LabourRepository();

  bool _loading = true;
  int _draftCount = 0;
  int _confirmedCount = 0;
  int _materialCount = 0;
  int _labourCount = 0;
  List<_RecentEstimate> _recent = const [];

  @override
  void initState() {
    super.initState();
    refresh();
  }

  /// Public so HomeScreen can call via GlobalKey when the dashboard tab
  /// becomes active again after data was changed elsewhere.
  Future<void> refresh() async {
    if (mounted) setState(() => _loading = true);
    final estimates = await _estimateRepo.findAll();
    final totals = await _estimateRepo.findTotalsByEstimate();
    final materials = await _materialRepo.findAll();
    final labours = await _labourRepo.findAll();

    if (!mounted) return;
    setState(() {
      _draftCount =
          estimates.where((e) => e.state == EstimateState.draft).length;
      _confirmedCount =
          estimates.where((e) => e.state == EstimateState.confirmed).length;
      _materialCount = materials.length;
      _labourCount = labours.length;
      _recent = estimates
          .take(5)
          .map((e) => _RecentEstimate(
                estimate: e,
                total: e.id != null ? (totals[e.id!]?.total ?? 0) : 0,
              ))
          .toList(growable: false);
      _loading = false;
    });
  }

  Future<void> _openEstimate(int id) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EstimateFormScreen(repository: _estimateRepo, estimateId: id),
      ),
    );
    if (saved == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverHeroAppBar(
            title: 'Dashboard',
            subtitle: 'EzEstimate',
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Settings',
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Settings')),
                        body: const SettingsScreen(),
                      ),
                    ),
                  );
                  // Restore from backup can replace all data — refresh on return.
                  refresh();
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _BackupReminderBanner(),
                _SectionLabel(text: 'Overview'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        label: 'Drafts',
                        value: _loading ? '—' : '$_draftCount',
                        icon: Icons.edit_note,
                        accent: scheme.primary,
                        onTap: () => widget.onNavigate?.call(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KpiCard(
                        label: 'Confirmed',
                        value: _loading ? '—' : '$_confirmedCount',
                        icon: Icons.check_circle_outline,
                        accent: scheme.tertiary,
                        onTap: () => widget.onNavigate?.call(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        label: 'Materials',
                        value: _loading ? '—' : '$_materialCount',
                        icon: Icons.inventory_2_outlined,
                        accent: scheme.secondary,
                        onTap: () => widget.onNavigate?.call(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: KpiCard(
                        label: 'Labour types',
                        value: _loading ? '—' : '$_labourCount',
                        icon: Icons.engineering_outlined,
                        accent: scheme.secondary,
                        onTap: () => widget.onNavigate?.call(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionLabel(
                  text: 'Recent estimates',
                  trailing: TextButton(
                    onPressed: () => widget.onNavigate?.call(4),
                    child: const Text('See all'),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_recent.isEmpty)
                  _RecentEmpty(onCreate: () => widget.onNavigate?.call(4))
                else
                  ..._recent.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RichListCard(
                        title: r.estimate.name,
                        subtitle: _recentSubtitle(r.estimate),
                        trailingPrimary: formatCurrency(r.total),
                        statusLabel: r.estimate.state.label,
                        statusColor: _statusColor(r.estimate.state, scheme),
                        leadingIcon: Icons.description_outlined,
                        onTap: r.estimate.id == null
                            ? null
                            : () => _openEstimate(r.estimate.id!),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _SectionLabel(text: 'Quick actions'),
                const SizedBox(height: 8),
                _QuickActions(onNavigate: widget.onNavigate),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static String _recentSubtitle(ProjectEstimate e) {
    final parts = <String>[];
    if (e.customerName != null && e.customerName!.isNotEmpty) {
      parts.add(e.customerName!);
    }
    if (e.date != null) {
      parts.add(DateFormat('d MMM').format(e.date!));
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  static Color _statusColor(EstimateState state, ColorScheme scheme) {
    return switch (state) {
      EstimateState.draft => scheme.outline,
      EstimateState.confirmed => scheme.tertiary,
      EstimateState.cancelled => scheme.error,
    };
  }
}

class _RecentEstimate {
  const _RecentEstimate({required this.estimate, required this.total});
  final ProjectEstimate estimate;
  final double total;
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                color: scheme.onSurfaceVariant, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Estimate မရှိသေးပါ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ပထမဆုံး estimate ဖန်တီးပါ',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onCreate,
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.8,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({this.onNavigate});

  final void Function(int tabIndex)? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.add_chart,
            title: 'New estimate',
            subtitle: 'Project cost calculation စတင်မယ်',
            onTap: () => onNavigate?.call(4),
          ),
          const Divider(height: 1),
          _ActionTile(
            icon: Icons.add_box_outlined,
            title: 'Add material',
            subtitle: 'Master data ထဲ material အသစ်ထည့်မယ်',
            onTap: () => onNavigate?.call(1),
          ),
          const Divider(height: 1),
          _ActionTile(
            icon: Icons.calculate_outlined,
            title: 'New AC template',
            subtitle: 'Reusable cost template ဖန်တီးမယ်',
            onTap: () => onNavigate?.call(3),
          ),
        ],
      ),
    );
  }
}

/// Reminder banner shown on the dashboard when no backup has been taken
/// in the last 7 days. Tapping it opens the Settings screen so the user
/// can run an export.
class _BackupReminderBanner extends StatefulWidget {
  const _BackupReminderBanner();

  @override
  State<_BackupReminderBanner> createState() => _BackupReminderBannerState();
}

class _BackupReminderBannerState extends State<_BackupReminderBanner> {
  final _backup = BackupService();
  bool _show = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final due = await _backup.needsBackupReminder();
    if (!mounted) return;
    setState(() {
      _show = due;
      _checked = true;
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: const SettingsScreen(),
        ),
      ),
    );
    if (!mounted) return;
    _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_show) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openSettings,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_outlined,
                    color: scheme.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup overdue',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '7 ရက်ထက် ပိုကြာပြီ။ Settings → Backup ကို သွား export လုပ်ပါ။',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: scheme.onTertiaryContainer, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
