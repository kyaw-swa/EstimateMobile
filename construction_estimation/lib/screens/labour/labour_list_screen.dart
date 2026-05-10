import 'package:flutter/material.dart';

import '../../models/labour.dart';
import '../../repositories/labour_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/numeric_field.dart';
import '../../widgets/sliver_hero_app_bar.dart';
import 'labour_form_screen.dart';

class LabourListScreen extends StatefulWidget {
  const LabourListScreen({super.key, this.repository});

  final LabourRepository? repository;

  @override
  State<LabourListScreen> createState() => _LabourListScreenState();
}

class _LabourListScreenState extends State<LabourListScreen> {
  late final LabourRepository _repo = widget.repository ?? LabourRepository();

  final TextEditingController _searchCtl = TextEditingController();

  List<Labour> _items = const [];
  bool _loading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.findAll(
      activeOnly: !_showArchived,
      search: _searchCtl.text,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openForm({Labour? labour}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LabourFormScreen(repository: _repo, labour: labour),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Labour labour) async {
    final id = labour.id;
    if (id == null) return;

    final references = await _repo.countReferences(id);
    if (!mounted) return;

    if (references > 0) {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Archive ${labour.name}?',
        message:
            'ဒီ labour ကို record $references ခုက သုံးထားလို့ delete မလုပ်နိုင်ပါ။\n\n'
            'Archive လုပ်ထားရင် list မှာ ပုံမှန်အားဖြင့် မပြတော့ပေမယ့် '
            'ရှိပြီးသား record တွေ ဆက်အသုံးပြုနိုင်ပါတယ်။',
        confirmLabel: 'Archive',
        icon: Icons.archive_outlined,
      );
      if (!ok) return;
      await _repo.archive(id);
    } else {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Delete ${labour.name}?',
        message: 'ဒီ labour ကို permanently ဖျက်မှာပါ။ ပြန်မရတော့ပါ။',
        confirmLabel: 'Delete',
        destructive: true,
        icon: Icons.delete_outline,
      );
      if (!ok) return;
      await _repo.delete(id);
    }
    if (!mounted) return;
    _load();
  }

  Future<void> _toggleActive(Labour labour) async {
    final id = labour.id;
    if (id == null) return;
    if (labour.active) {
      await _repo.archive(id);
    } else {
      await _repo.unarchive(id);
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverHeroAppBar(
            title: 'Labour',
            subtitle: 'Master data',
            actions: [
              IconButton(
                tooltip: _showArchived ? 'Hide archived' : 'Show archived',
                icon: Icon(
                  _showArchived
                      ? Icons.visibility_off_outlined
                      : Icons.archive_outlined,
                ),
                onPressed: () {
                  setState(() => _showArchived = !_showArchived);
                  _load();
                },
              ),
            ],
          ),
          SliverToBoxAdapter(child: _buildSearch()),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.engineering_outlined,
                title: 'No labour types yet',
                message: _searchCtl.text.isNotEmpty
                    ? 'Search query နဲ့ ကိုက်ညီတဲ့ labour မရှိပါ'
                    : 'ပထမဆုံး labour type ထည့်ပါ',
                actionLabel: 'Add Labour',
                onAction: () => _openForm(),
              ),
            )
          else
            SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
                indent: 72,
              ),
              itemBuilder: (ctx, i) => _buildTile(_items[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Labour'),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchCtl,
        decoration: InputDecoration(
          hintText: 'Search labour types...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtl.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtl.clear();
                    _load();
                  },
                ),
        ),
        onChanged: (_) => _load(),
        textInputAction: TextInputAction.search,
      ),
    );
  }

  Widget _buildTile(Labour labour) {
    final scheme = Theme.of(context).colorScheme;
    final uomLabel = labour.uomName ?? '—';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: const Icon(Icons.engineering_outlined),
      ),
      title: Text(
        labour.name,
        style: TextStyle(
          decoration: labour.active ? null : TextDecoration.lineThrough,
          color: labour.active ? null : scheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text('per $uomLabel'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(labour.defaultRate),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          PopupMenuButton<_TileAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _TileAction.edit:
                  _openForm(labour: labour);
                case _TileAction.toggleActive:
                  _toggleActive(labour);
                case _TileAction.delete:
                  _confirmDelete(labour);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _TileAction.edit,
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: _TileAction.toggleActive,
                child: ListTile(
                  leading: Icon(
                    labour.active
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                  title: Text(labour.active ? 'Archive' : 'Unarchive'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _TileAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text('Delete', style: TextStyle(color: scheme.error)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => _openForm(labour: labour),
    );
  }
}

enum _TileAction { edit, toggleActive, delete }
