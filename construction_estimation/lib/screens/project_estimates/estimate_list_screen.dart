import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/project_estimate.dart';
import '../../repositories/project_estimate_repository.dart';
import '../../services/boq_pdf_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/numeric_field.dart';
import '../../widgets/sliver_hero_app_bar.dart';
import 'estimate_form_screen.dart';

class EstimateListScreen extends StatefulWidget {
  const EstimateListScreen({super.key, this.repository});

  final ProjectEstimateRepository? repository;

  @override
  State<EstimateListScreen> createState() => _EstimateListScreenState();
}

class _EstimateListScreenState extends State<EstimateListScreen> {
  late final ProjectEstimateRepository _repo =
      widget.repository ?? ProjectEstimateRepository();

  final TextEditingController _searchCtl = TextEditingController();

  List<ProjectEstimate> _items = const [];
  Map<int, ({double material, double labour, double total, int lines})>
      _totals = const {};
  EstimateState? _stateFilter;
  bool _loading = true;

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
      state: _stateFilter,
      search: _searchCtl.text,
    );
    final totals = await _repo.findTotalsByEstimate();
    if (!mounted) return;
    setState(() {
      _items = items;
      _totals = totals;
      _loading = false;
    });
  }

  Future<void> _openForm({int? id}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EstimateFormScreen(repository: _repo, estimateId: id),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _printBoq(ProjectEstimate est) async {
    final id = est.id;
    if (id == null) return;
    final full = await _repo.findById(id);
    if (!mounted || full == null) return;
    if (full.lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work item မရှိသေးပါ။')),
      );
      return;
    }
    try {
      await BoqPdfService().preview(full);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF preview failed: $e')),
      );
    }
  }

  Future<void> _confirmDelete(ProjectEstimate est) async {
    final id = est.id;
    if (id == null) return;
    final ok = await ConfirmDialog.show(
      context,
      title: 'Delete ${est.name}?',
      message:
          'ဒီ estimate နဲ့ ၎င်းရဲ့ lines, material/labour details အားလုံး '
          'permanently ဖျက်မှာပါ။ ပြန်မရတော့ပါ။',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    await _repo.delete(id);
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverHeroAppBar(
            title: 'Project Estimates',
            subtitle: 'Cost estimates per project',
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
                icon: Icons.description_outlined,
                title: 'No estimates yet',
                message: _searchCtl.text.isNotEmpty || _stateFilter != null
                    ? 'Filter ပြောင်းကြည့်ပါ'
                    : 'ပထမဆုံး estimate ထည့်ပါ',
                actionLabel: 'Add Estimate',
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
        label: const Text('Add Estimate'),
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
              hintText: 'Search by name or customer...',
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
                _stateChip(null, 'All'),
                const SizedBox(width: 6),
                _stateChip(EstimateState.draft, 'Draft'),
                const SizedBox(width: 6),
                _stateChip(EstimateState.confirmed, 'Confirmed'),
                const SizedBox(width: 6),
                _stateChip(EstimateState.cancelled, 'Cancelled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateChip(EstimateState? state, String label) {
    final selected = _stateFilter == state;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _stateFilter = state);
        _load();
      },
    );
  }

  Widget _buildTile(ProjectEstimate est) {
    final scheme = Theme.of(context).colorScheme;
    final id = est.id;
    final totals = (id != null ? _totals[id] : null) ??
        (material: 0.0, labour: 0.0, total: 0.0, lines: 0);
    final dateStr = est.date != null
        ? DateFormat('d MMM yyyy').format(est.date!)
        : '—';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: _stateColor(est.state, scheme).$1,
        foregroundColor: _stateColor(est.state, scheme).$2,
        child: Icon(_stateIcon(est.state)),
      ),
      title: Text(
        est.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                if (est.customerName != null && est.customerName!.isNotEmpty)
                  est.customerName!,
                dateStr,
                '${totals.lines} ${totals.lines == 1 ? "line" : "lines"}',
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _StateBadge(state: est.state),
                const SizedBox(width: 6),
                Text(
                  formatCurrency(totals.total),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      trailing: PopupMenuButton<_TileAction>(
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          switch (action) {
            case _TileAction.edit:
              _openForm(id: est.id);
            case _TileAction.printBoq:
              _printBoq(est);
            case _TileAction.delete:
              _confirmDelete(est);
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
          const PopupMenuItem(
            value: _TileAction.printBoq,
            child: ListTile(
              leading: Icon(Icons.picture_as_pdf_outlined),
              title: Text('Print BOQ'),
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
      onTap: () => _openForm(id: est.id),
    );
  }

  /// (background, foreground) for the avatar.
  (Color, Color) _stateColor(EstimateState state, ColorScheme scheme) {
    return switch (state) {
      EstimateState.draft => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      EstimateState.confirmed => (scheme.primaryContainer, scheme.onPrimaryContainer),
      EstimateState.cancelled => (scheme.errorContainer, scheme.onErrorContainer),
    };
  }

  IconData _stateIcon(EstimateState state) {
    return switch (state) {
      EstimateState.draft => Icons.edit_note_outlined,
      EstimateState.confirmed => Icons.check_circle_outline,
      EstimateState.cancelled => Icons.cancel_outlined,
    };
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state});

  final EstimateState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (state) {
      EstimateState.draft => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant
        ),
      EstimateState.confirmed => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer
        ),
      EstimateState.cancelled => (
          scheme.errorContainer,
          scheme.onErrorContainer
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

enum _TileAction { edit, printBoq, delete }
