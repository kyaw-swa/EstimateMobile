import 'package:flutter/material.dart' hide Material;

import '../../models/material.dart';
import '../../repositories/material_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/numeric_field.dart';
import '../../widgets/sliver_hero_app_bar.dart';
import 'material_form_screen.dart';

class MaterialListScreen extends StatefulWidget {
  const MaterialListScreen({super.key, this.repository});

  final MaterialRepository? repository;

  @override
  State<MaterialListScreen> createState() => _MaterialListScreenState();
}

class _MaterialListScreenState extends State<MaterialListScreen> {
  late final MaterialRepository _repo = widget.repository ?? MaterialRepository();

  final TextEditingController _searchCtl = TextEditingController();

  List<Material> _items = const [];
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

  Future<void> _openForm({Material? material}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaterialFormScreen(repository: _repo, material: material),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(Material material) async {
    final id = material.id;
    if (id == null) return;

    final references = await _repo.countReferences(id);
    if (!mounted) return;

    if (references > 0) {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Archive ${material.name}?',
        message:
            'ဒီ material ကို record $references ခုက သုံးထားလို့ delete မလုပ်နိုင်ပါ။\n\n'
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
        title: 'Delete ${material.name}?',
        message: 'ဒီ material ကို permanently ဖျက်မှာပါ။ ပြန်မရတော့ပါ။',
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

  Future<void> _toggleActive(Material material) async {
    final id = material.id;
    if (id == null) return;
    if (material.active) {
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
            title: 'Materials',
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
                icon: Icons.inventory_2_outlined,
                title: 'No materials yet',
                message: _searchCtl.text.isNotEmpty
                    ? 'Search query နဲ့ ကိုက်ညီတဲ့ material မရှိပါ'
                    : 'ပထမဆုံး material ထည့်ပါ',
                actionLabel: 'Add Material',
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
        label: const Text('Add Material'),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchCtl,
        decoration: InputDecoration(
          hintText: 'Search materials...',
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

  Widget _buildTile(Material material) {
    final scheme = Theme.of(context).colorScheme;
    final uomLabel = material.uomName ?? '—';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: const Icon(Icons.inventory_2_outlined),
      ),
      title: Text(
        material.name,
        style: TextStyle(
          decoration: material.active ? null : TextDecoration.lineThrough,
          color: material.active ? null : scheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text('per $uomLabel'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCurrency(material.defaultRate),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          PopupMenuButton<_TileAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _TileAction.edit:
                  _openForm(material: material);
                case _TileAction.toggleActive:
                  _toggleActive(material);
                case _TileAction.delete:
                  _confirmDelete(material);
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
                    material.active
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                  ),
                  title: Text(material.active ? 'Archive' : 'Unarchive'),
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
      onTap: () => _openForm(material: material),
    );
  }
}

enum _TileAction { edit, toggleActive, delete }
