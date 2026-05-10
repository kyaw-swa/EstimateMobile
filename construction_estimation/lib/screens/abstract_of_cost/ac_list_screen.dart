import 'package:flutter/material.dart';

import '../../models/abstract_of_cost.dart';
import '../../repositories/abstract_of_cost_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/sliver_hero_app_bar.dart';
import 'ac_form_screen.dart';

class AcListScreen extends StatefulWidget {
  const AcListScreen({super.key, this.repository});

  final AbstractOfCostRepository? repository;

  @override
  State<AcListScreen> createState() => _AcListScreenState();
}

class _AcListScreenState extends State<AcListScreen> {
  late final AbstractOfCostRepository _repo =
      widget.repository ?? AbstractOfCostRepository();

  final TextEditingController _searchCtl = TextEditingController();

  List<AbstractOfCost> _items = const [];
  Map<int, ({int materials, int labour})> _counts = const {};
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
    final counts = await _repo.countLinesByAc();
    if (!mounted) return;
    setState(() {
      _items = items;
      _counts = counts;
      _loading = false;
    });
  }

  Future<void> _openForm({AbstractOfCost? ac}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AcFormScreen(repository: _repo, acId: ac?.id),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _confirmDelete(AbstractOfCost ac) async {
    final id = ac.id;
    if (id == null) return;

    final references = await _repo.countReferences(id);
    if (!mounted) return;

    if (references > 0) {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Archive ${ac.name}?',
        message:
            'ဒီ A/C ကို estimate line $references ခုက သုံးထားလို့ delete မလုပ်နိုင်ပါ။\n\n'
            'Archive လုပ်ထားရင် list မှာ ပုံမှန်အားဖြင့် မပြတော့ပေမယ့် '
            'ရှိပြီးသား estimate တွေ ဆက်အသုံးပြုနိုင်ပါတယ်။',
        confirmLabel: 'Archive',
        icon: Icons.archive_outlined,
      );
      if (!ok) return;
      await _repo.archive(id);
    } else {
      final ok = await ConfirmDialog.show(
        context,
        title: 'Delete ${ac.name}?',
        message: 'ဒီ A/C နဲ့ ၎င်းရဲ့ material/labour lines တွေ permanently '
            'ဖျက်မှာပါ။ ပြန်မရတော့ပါ။',
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

  Future<void> _toggleActive(AbstractOfCost ac) async {
    final id = ac.id;
    if (id == null) return;
    if (ac.active) {
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
            title: 'Abstract of Cost',
            subtitle: 'Reusable cost templates',
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
                icon: Icons.calculate_outlined,
                title: 'No A/C templates yet',
                message: _searchCtl.text.isNotEmpty
                    ? 'Search query နဲ့ ကိုက်ညီတဲ့ A/C မရှိပါ'
                    : 'ပထမဆုံး cost template ထည့်ပါ',
                actionLabel: 'Add A/C',
                onAction: () => _openForm(),
              ),
            )
          else
            SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (ctx, i) => _buildTile(_items[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add A/C'),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchCtl,
        decoration: InputDecoration(
          hintText: 'Search A/C templates...',
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

  Widget _buildTile(AbstractOfCost ac) {
    final scheme = Theme.of(context).colorScheme;
    final id = ac.id;
    final counts = (id != null ? _counts[id] : null) ??
        (materials: 0, labour: 0);
    final baseLabel = '${ac.baseQuantity.toStringAsFixed(0)} '
        '${ac.baseUomName ?? ac.measurementType.label.split(' ').first}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: scheme.tertiaryContainer,
        foregroundColor: scheme.onTertiaryContainer,
        child: const Icon(Icons.calculate_outlined),
      ),
      title: Text(
        ac.name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: ac.active ? null : TextDecoration.lineThrough,
          color: ac.active ? null : scheme.onSurfaceVariant,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _Chip(
              icon: Icons.straighten,
              label: 'Per $baseLabel',
            ),
            _Chip(
              icon: Icons.inventory_2_outlined,
              label: '${counts.materials} materials',
            ),
            _Chip(
              icon: Icons.engineering_outlined,
              label: '${counts.labour} labour',
            ),
          ],
        ),
      ),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case _TileAction.edit:
              _openForm(ac: ac);
            case _TileAction.toggleActive:
              _toggleActive(ac);
            case _TileAction.delete:
              _confirmDelete(ac);
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
                ac.active
                    ? Icons.archive_outlined
                    : Icons.unarchive_outlined,
              ),
              title: Text(ac.active ? 'Archive' : 'Unarchive'),
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
      onTap: () => _openForm(ac: ac),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: scheme.onSurface),
          ),
        ],
      ),
    );
  }
}

enum _TileAction { edit, toggleActive, delete }
