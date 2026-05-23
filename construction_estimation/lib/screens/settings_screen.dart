import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../services/backup_service.dart';
import '../widgets/confirm_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, BackupService? backupService})
      : _backupService = backupService;

  final BackupService? _backupService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            _MenuTile(
              icon: Icons.storage_outlined,
              title: 'Database',
              subtitle: 'Re-seed default data၊ database reset',
              onTap: () => _open(
                context,
                'Database',
                const _DatabaseSettingsScreen(),
              ),
            ),
            const _Divider(),
            _MenuTile(
              icon: Icons.cloud_sync_outlined,
              title: 'Backup & Restore',
              subtitle: 'Data ကို export/restore လုပ်ရန်',
              onTap: () => _open(
                context,
                'Backup & Restore',
                _BackupRestoreScreen(backupService: _backupService),
              ),
            ),
            const _Divider(),
            _MenuTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'App version နှင့် credits',
              onTap: () => _open(context, 'About', const _AboutScreen()),
            ),
          ],
        ),
      ],
    );
  }

  void _open(BuildContext context, String title, Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: body,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ──────────────────── Database screen ────────────────────

class _DatabaseSettingsScreen extends StatefulWidget {
  const _DatabaseSettingsScreen();

  @override
  State<_DatabaseSettingsScreen> createState() =>
      _DatabaseSettingsScreenState();
}

class _DatabaseSettingsScreenState extends State<_DatabaseSettingsScreen>
    with _BusyOverlayMixin {
  Future<void> _reseedDefaultData() async {
    final messenger = ScaffoldMessenger.of(context);
    await run('Re-seed', () async {
      await DatabaseHelper.instance.ensureDefaultData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Default UoMs, Materials, Labour ensured.')),
      );
    });
  }

  Future<void> _resetDatabase() async {
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
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await run('Reset', () async {
      await DatabaseHelper.instance.deleteAndRecreate();
      messenger.showSnackBar(
        const SnackBar(content: Text('Database reset complete.')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
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
                  enabled: !busy,
                  onTap: _reseedDefaultData,
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
                  enabled: !busy,
                  onTap: _resetDatabase,
                ),
              ],
            ),
          ],
        ),
        busyOverlay(),
      ],
    );
  }
}

// ──────────────────── Backup & Restore screen ────────────────────

class _BackupRestoreScreen extends StatefulWidget {
  const _BackupRestoreScreen({BackupService? backupService})
      : _backupService = backupService;

  final BackupService? _backupService;

  @override
  State<_BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<_BackupRestoreScreen>
    with _BusyOverlayMixin {
  late final BackupService _backup = widget._backupService ?? BackupService();
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _refreshLastBackup();
  }

  Future<void> _refreshLastBackup() async {
    final last = await _backup.lastBackupAt();
    if (!mounted) return;
    setState(() => _lastBackupAt = last);
  }

  Future<void> _exportDb() =>
      run('Export DB', _backup.shareDatabaseFile, after: _refreshLastBackup);
  Future<void> _exportJson() =>
      run('Export JSON', _backup.shareJson, after: _refreshLastBackup);
  Future<void> _exportCsv() =>
      run('Export CSV', _backup.shareCsv, after: _refreshLastBackup);

  Future<void> _restore() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['db', 'sqlite', 'sqlite3', 'json'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    if (!mounted) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Restore from backup?',
      message: 'လက်ရှိ data အားလုံးကို ဖျက်ပြီး ဒီ file ထဲက data နဲ့ '
          'အစားထိုးပါမယ်။ ပြန်မရတော့ပါ။',
      confirmLabel: 'Restore',
      destructive: true,
      icon: Icons.restore_outlined,
    );
    if (!confirmed || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await run('Restore', () async {
      await _backup.restoreFrom(path);
      messenger.showSnackBar(
        const SnackBar(content: Text('Restore complete. Reopen the app for a clean slate.')),
      );
    }, after: _refreshLastBackup);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SectionCard(
              children: [
                _BackupStatusTile(lastBackupAt: _lastBackupAt),
                const _Divider(),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: const Text('Export database file'),
                  subtitle: const Text(
                    'Raw .db file ကို share — အမြန်ဆုံး၊ အပြည့်စုံဆုံး',
                  ),
                  trailing: const Icon(Icons.share),
                  enabled: !busy,
                  onTap: _exportDb,
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(Icons.data_object),
                  title: const Text('Export to JSON'),
                  subtitle: const Text(
                    'Human-readable၊ schema-compatible builds တွေကြားမှာ portable',
                  ),
                  trailing: const Icon(Icons.share),
                  enabled: !busy,
                  onTap: _exportJson,
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined),
                  title: const Text('Export to CSV'),
                  subtitle: const Text(
                    'Table တစ်ခုစီအတွက် .csv တစ်ဖိုင်စီ',
                  ),
                  trailing: const Icon(Icons.share),
                  enabled: !busy,
                  onTap: _exportCsv,
                ),
                const _Divider(),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore from backup'),
                  subtitle: const Text(
                    '.db သို့မဟုတ် .json file ကို ရွေး — data အားလုံး အစားထိုးပါမယ်',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  enabled: !busy,
                  onTap: _restore,
                ),
              ],
            ),
          ],
        ),
        busyOverlay(),
      ],
    );
  }
}

// ──────────────────── About screen ────────────────────

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: const [
        _SectionCard(
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
            _Divider(),
            ListTile(
              leading: Icon(Icons.person_outline),
              title: Text('Developed by'),
              subtitle: Text('Phoe Ku'),
            ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────── Shared helpers ────────────────────

mixin _BusyOverlayMixin<T extends StatefulWidget> on State<T> {
  bool _busy = false;
  String? _busyLabel;

  bool get busy => _busy;

  Future<void> run(
    String label,
    Future<void> Function() action, {
    Future<void> Function()? after,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (after != null) await after();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$label failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busyLabel = null;
        });
      }
    }
  }

  Widget busyOverlay() {
    if (!_busy) return const SizedBox.shrink();
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(_busyLabel ?? 'Working...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackupStatusTile extends StatelessWidget {
  const _BackupStatusTile({required this.lastBackupAt});

  final DateTime? lastBackupAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = lastBackupAt;
    final overdue = last == null ||
        DateTime.now().difference(last) >= const Duration(days: 7);
    final color = overdue ? scheme.error : scheme.primary;
    final label = last == null
        ? 'Never backed up'
        : 'Last backup: ${DateFormat('d MMM yyyy, h:mm a').format(last)}';
    final hint = last == null
        ? 'ပထမဆုံး backup တစ်ခု ထုတ်ထားပါ'
        : overdue
            ? '7 ရက်ထက် ပိုကြာပြီ — backup အသစ်ထုတ်ပါ'
            : 'Up to date';

    return ListTile(
      leading: Icon(
        overdue ? Icons.warning_amber_outlined : Icons.verified_outlined,
        color: color,
      ),
      title: Text(label, style: TextStyle(color: color)),
      subtitle: Text(hint),
      dense: true,
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
