import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../services/backup_service.dart';
import '../widgets/confirm_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, BackupService? backupService})
      : _backupService = backupService;

  final BackupService? _backupService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final BackupService _backup = widget._backupService ?? BackupService();

  DateTime? _lastBackupAt;
  bool _busy = false;
  String? _busyLabel;

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

  Future<void> _run(String label, Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      await _refreshLastBackup();
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

  // ──────────── Database actions ────────────

  Future<void> _reseedDefaultData() async {
    final messenger = ScaffoldMessenger.of(context);
    await _run('Re-seed', () async {
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
    await _run('Reset', () async {
      await DatabaseHelper.instance.deleteAndRecreate();
      messenger.showSnackBar(
        const SnackBar(content: Text('Database reset complete.')),
      );
    });
  }

  // ──────────── Backup actions ────────────

  Future<void> _exportDb() => _run('Export DB', _backup.shareDatabaseFile);
  Future<void> _exportJson() => _run('Export JSON', _backup.shareJson);
  Future<void> _exportCsv() => _run('Export CSV', _backup.shareCsv);

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
    await _run('Restore', () async {
      await _backup.restoreFrom(path);
      messenger.showSnackBar(
        const SnackBar(content: Text('Restore complete. Reopen the app for a clean slate.')),
      );
    });
  }

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        ListView(
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
                  enabled: !_busy,
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
                  enabled: !_busy,
                  onTap: _resetDatabase,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _SectionHeader(title: 'Backup & Restore'),
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
                  enabled: !_busy,
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
                  enabled: !_busy,
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
                  enabled: !_busy,
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
                  enabled: !_busy,
                  onTap: _restore,
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
        ),
        if (_busy)
          Positioned.fill(
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
          ),
      ],
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
