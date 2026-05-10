import 'package:flutter/material.dart';

import '../../models/uom.dart';
import '../../repositories/uom_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/sliver_hero_app_bar.dart';
import 'uom_form_screen.dart';

class UomListScreen extends StatefulWidget {
  const UomListScreen({super.key, this.repository});

  final UomRepository? repository;

  @override
  State<UomListScreen> createState() => _UomListScreenState();
}

class _UomListScreenState extends State<UomListScreen> {
  late final UomRepository _repo = widget.repository ?? UomRepository();

  final TextEditingController _searchCtl = TextEditingController();

  List<UnitOfMeasure> _items = const [];
  bool _loading = true;
  bool _showArchived = false;
  UomType? _typeFilter;

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
      type: _typeFilter,
      search: _searchCtl.text,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _openForm({UnitOfMeasure? uom}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UomFormScreen(repository: _repo, uom: uom),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(UnitOfMeasure uom) async {
    final id = uom.id;
    if (id == null) return;

    final references = await _repo.countReferences(id);
    if (!mounted) return;

    if (references > 0) {
      // Has FK references — must archive instead.
      final ok = await ConfirmDialog.show(
        context,
        title: 'Archive ${uom.name}?',
        message:
            'ဒီ UoM ကို record $references ခုက သုံးထားလို့ delete မလုပ်နိုင်ပါ။\n\n'
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
        title: 'Delete ${uom.name}?',
        message: 'ဒီ UoM ကို permanently ဖျက်မှာပါ။ ပြန်မရတော့ပါ။',
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

  Future<void> _toggleActive(UnitOfMeasure uom) async {
    final id = uom.id;
    if (id == null) return;
    if (uom.active) {
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
            title: 'Units of Measure',
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
          SliverToBoxAdapter(child: _buildFilters()),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.straighten_outlined,
                title: 'No UoMs found',
                message: _searchCtl.text.isNotEmpty || _typeFilter != null
                    ? 'Filter ပြောင်းကြည့်ပါ'
                    : 'ပထမဆုံး UoM ထည့်ပါ',
                actionLabel: 'Add UoM',
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
        label: const Text('Add UoM'),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchCtl,
            decoration: InputDecoration(
              hintText: 'Search by name...',
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
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _typeChip(null, 'All'),
                const SizedBox(width: 6),
                _typeChip(UomType.material, 'Material'),
                const SizedBox(width: 6),
                _typeChip(UomType.labour, 'Labour'),
                const SizedBox(width: 6),
                _typeChip(UomType.both, 'Both'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(UomType? type, String label) {
    final selected = _typeFilter == type;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _typeFilter = type);
        _load();
      },
    );
  }

  Widget _buildTile(UnitOfMeasure uom) {
    final scheme = Theme.of(context).colorScheme;
    final iconData = switch (uom.uomType) {
      UomType.material => Icons.inventory_2_outlined,
      UomType.labour => Icons.engineering_outlined,
      UomType.both => Icons.swap_horiz,
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Icon(iconData),
      ),
      title: Text(
        uom.name,
        style: TextStyle(
          decoration: uom.active ? null : TextDecoration.lineThrough,
          color: uom.active ? null : scheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(uom.uomType.label),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case _TileAction.edit:
              _openForm(uom: uom);
            case _TileAction.toggleActive:
              _toggleActive(uom);
            case _TileAction.delete:
              _confirmDelete(uom);
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
                uom.active
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
              ),
              title: Text(uom.active ? 'Archive' : 'Unarchive'),
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
      onTap: () => _openForm(uom: uom),
    );
  }
}

enum _TileAction { edit, toggleActive, delete }
