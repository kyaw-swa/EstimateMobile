import 'package:flutter/material.dart';

import '../services/backup_service.dart';
import '../widgets/kpi_card.dart';
import '../widgets/rich_list_card.dart';
import '../widgets/sliver_hero_app_bar.dart';
import 'settings_screen.dart';

/// Dashboard — entry screen with KPIs, recent estimates, quick actions.
///
/// Sample data is shown until repositories are wired up (Phase 4).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onNavigate});

  /// Tab-switch callback wired by HomeScreen — index follows _destinations order
  /// (1 = Materials, 2 = Labour, 3 = AC, 4 = Estimates).
  final void Function(int tabIndex)? onNavigate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverHeroAppBar(
          title: 'Dashboard',
          subtitle: 'EzEstimate',
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Settings')),
                    body: const SettingsScreen(),
                  ),
                ),
              ),
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
                      value: '0',
                      icon: Icons.edit_note,
                      accent: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      label: 'Confirmed',
                      value: '0',
                      icon: Icons.check_circle_outline,
                      accent: scheme.tertiary,
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
                      value: '0',
                      icon: Icons.inventory_2_outlined,
                      accent: scheme.secondary,
                      onTap: () => onNavigate?.call(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: KpiCard(
                      label: 'Labour types',
                      value: '0',
                      icon: Icons.engineering_outlined,
                      accent: scheme.secondary,
                      onTap: () => onNavigate?.call(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionLabel(
                text: 'Recent estimates',
                trailing: TextButton(
                  onPressed: () => onNavigate?.call(4),
                  child: const Text('See all'),
                ),
              ),
              const SizedBox(height: 8),
              ..._sampleRecent.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RichListCard(
                    title: e.title,
                    subtitle: e.subtitle,
                    trailingPrimary: e.amount,
                    statusLabel: e.status,
                    statusColor: _statusColor(e.status, scheme),
                    leadingIcon: Icons.description_outlined,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SectionLabel(text: 'Quick actions'),
              const SizedBox(height: 8),
              _QuickActions(onNavigate: onNavigate),
            ]),
          ),
        ),
      ],
    );
  }

  static Color _statusColor(String status, ColorScheme scheme) {
    switch (status.toLowerCase()) {
      case 'draft':
        return scheme.outline;
      case 'confirmed':
        return scheme.tertiary;
      case 'done':
        return scheme.primary;
      default:
        return scheme.secondary;
    }
  }
}

class _SampleEstimate {
  const _SampleEstimate(this.title, this.subtitle, this.amount, this.status);
  final String title;
  final String subtitle;
  final String amount;
  final String status;
}

const _sampleRecent = <_SampleEstimate>[
  _SampleEstimate(
      '(Sample) Ko Aung House', 'EST/2026/003 · May 8', 'K 2.15M', 'Draft'),
  _SampleEstimate(
      '(Sample) Office Building', 'EST/2026/002 · May 4', 'K 8.04M', 'Done'),
  _SampleEstimate('(Sample) Warehouse Extension', 'EST/2026/001 · Apr 28',
      'K 1.20M', 'Confirmed'),
];

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
