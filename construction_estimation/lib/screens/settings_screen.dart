import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../widgets/confirm_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _reseedDefaultData(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await DatabaseHelper.instance.ensureDefaultData();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Default UoMs, Materials, Labour ensured.'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Re-seed failed: $e')),
      );
    }
  }

  Future<void> _resetDatabase(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reset database?',
      message: 'အားလုံးကို ဖျက်ပြီး schema + default seed အသစ်ပြန်တည်ဆောက်မယ်။\n\n'
          'Materials, Labour, Estimates အပါအဝင် တခြား data အားလုံးပျောက်မယ်။\n\n'
          'ပြန်မရတော့ပါ။',
      confirmLabel: 'Reset',
      destructive: true,
      icon: Icons.delete_forever_outlined,
    );
    if (!confirmed) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await DatabaseHelper.instance.deleteAndRecreate();
      messenger.showSnackBar(
        const SnackBar(content: Text('Database reset complete.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Reset failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const _SectionHeader(title: 'Database'),
        _SectionCard(
          children: [
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('Re-seed default data'),
              subtitle: const Text(
                'Empty table တွေထဲကို default UoMs, Materials, Labour ထည့်မယ် — '
                'ရှိပြီးသား data ကို မထိ',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _reseedDefaultData(context),
            ),
            const _Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: scheme.error,
              ),
              title: Text(
                'Reset database',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: const Text(
                'Schema + seed အသစ်ပြန်တည်ဆောက် — data အားလုံးပျောက်မယ်',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _resetDatabase(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Backup & Restore'),
        const _SectionCard(
          children: [
            _DisabledTile(
              icon: Icons.backup_outlined,
              title: 'Export database',
              subtitle: 'Phase 6 မှာ ဖြည့်မယ်',
            ),
            _Divider(),
            _DisabledTile(
              icon: Icons.restore_outlined,
              title: 'Restore from backup',
              subtitle: 'Phase 6 မှာ ဖြည့်မယ်',
            ),
            _Divider(),
            _DisabledTile(
              icon: Icons.file_download_outlined,
              title: 'Export to CSV / JSON',
              subtitle: 'Phase 6 မှာ ဖြည့်မယ်',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'About'),
        const _SectionCard(
          children: [
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('EzEstimate'),
              subtitle: Text('Version 1.0.0'),
            ),
            _Divider(),
            ListTile(
              leading: Icon(Icons.code),
              title: Text('Built with Flutter + sqflite'),
              subtitle: Text('Local-only, no online sync'),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60),
      child: Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    );
  }
}

class _DisabledTile extends StatelessWidget {
  const _DisabledTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      enabled: false,
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
