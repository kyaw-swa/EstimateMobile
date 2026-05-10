import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../../models/labour.dart';
import '../../models/material.dart';
import '../../models/project_estimate.dart';
import '../../repositories/labour_repository.dart';
import '../../repositories/material_repository.dart';
import '../../widgets/numeric_field.dart';

/// Edit one EstimateLine — dimensions + material/labour details.
///
/// Returns the updated [EstimateLine] (or null if cancelled).
class EstimateLineFormScreen extends StatefulWidget {
  const EstimateLineFormScreen({
    super.key,
    required this.initialLine,
    this.materialRepository,
    this.labourRepository,
  });

  final EstimateLine initialLine;
  final MaterialRepository? materialRepository;
  final LabourRepository? labourRepository;

  @override
  State<EstimateLineFormScreen> createState() =>
      _EstimateLineFormScreenState();
}

class _EstimateLineFormScreenState extends State<EstimateLineFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _refCtl = TextEditingController();
  late final TabController _tabs;

  late final MaterialRepository _matRepo =
      widget.materialRepository ?? MaterialRepository();
  late final LabourRepository _labRepo =
      widget.labourRepository ?? LabourRepository();

  late EstimateLine _line;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _line = widget.initialLine;
    _refCtl.text = _line.reference ?? '';
  }

  @override
  void dispose() {
    _tabs.dispose();
    _refCtl.dispose();
    super.dispose();
  }

  // ──────────── Mutators (always sync details' parentBaseQty) ────────────

  /// Re-derive the line so detail.parentBaseQty stays current.
  /// Must be called after any dimension/manualQty change.
  void _refreshDetails() {
    final base = _line.baseQty;
    setState(() {
      _line = _line.copyWith(
        materialDetails: [
          for (final d in _line.materialDetails)
            d.copyWith(parentBaseQty: base),
        ],
        labourDetails: [
          for (final d in _line.labourDetails)
            d.copyWith(parentBaseQty: base),
        ],
      );
    });
  }

  void _patchLine(EstimateLine Function(EstimateLine) update) {
    setState(() => _line = update(_line));
    _refreshDetails();
  }

  // ──────────── Material detail ops ────────────

  Future<void> _addMaterialDetail() async {
    final taken = _line.materialDetails.map((d) => d.materialId).toSet();
    final picked = await showModalBottomSheet<Material>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _GenericPickerSheet<Material>(
        label: 'Material',
        searchItems: (q) async {
          final all = await _matRepo.findAll(activeOnly: true, search: q);
          return all.where((m) => !taken.contains(m.id)).toList();
        },
        itemId: (m) => m.id!,
        itemLabel: (m) => m.name,
        itemSubtitle: (m) =>
            m.uomName != null ? 'per ${m.uomName}' : 'no UoM',
      ),
    );
    if (picked == null) return;
    setState(() {
      _line = _line.copyWith(
        materialDetails: [
          ..._line.materialDetails,
          EstimateLineMaterial(
            materialId: picked.id!,
            materialName: picked.name,
            uomName: picked.uomName,
            sequence: (_line.materialDetails.length + 1) * 10,
            templateQty: 0,
            templateBaseQty: 1,
            isManual: true,
            quantity: 0,
            rate: picked.defaultRate,
            parentBaseQty: _line.baseQty,
          ),
        ],
      );
    });
  }

  Future<void> _addLabourDetail() async {
    final taken = _line.labourDetails.map((d) => d.labourId).toSet();
    final picked = await showModalBottomSheet<Labour>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _GenericPickerSheet<Labour>(
        label: 'Labour',
        searchItems: (q) async {
          final all = await _labRepo.findAll(activeOnly: true, search: q);
          return all.where((l) => !taken.contains(l.id)).toList();
        },
        itemId: (l) => l.id!,
        itemLabel: (l) => l.name,
        itemSubtitle: (l) =>
            l.uomName != null ? 'per ${l.uomName}' : 'no UoM',
      ),
    );
    if (picked == null) return;
    setState(() {
      _line = _line.copyWith(
        labourDetails: [
          ..._line.labourDetails,
          EstimateLineLabour(
            labourId: picked.id!,
            labourName: picked.name,
            uomName: picked.uomName,
            sequence: (_line.labourDetails.length + 1) * 10,
            templateQty: 0,
            templateBaseQty: 1,
            isManual: true,
            quantity: 0,
            rate: picked.defaultRate,
            parentBaseQty: _line.baseQty,
          ),
        ],
      );
    });
  }

  void _replaceMaterial(int i, EstimateLineMaterial updated) {
    setState(() {
      final list = [..._line.materialDetails];
      list[i] = updated.copyWith(parentBaseQty: _line.baseQty);
      _line = _line.copyWith(materialDetails: list);
    });
  }

  void _replaceLabour(int i, EstimateLineLabour updated) {
    setState(() {
      final list = [..._line.labourDetails];
      list[i] = updated.copyWith(parentBaseQty: _line.baseQty);
      _line = _line.copyWith(labourDetails: list);
    });
  }

  void _removeMaterial(int i) {
    setState(() {
      final list = [..._line.materialDetails]..removeAt(i);
      _line = _line.copyWith(materialDetails: list);
    });
  }

  void _removeLabour(int i) {
    setState(() {
      final list = [..._line.labourDetails]..removeAt(i);
      _line = _line.copyWith(labourDetails: list);
    });
  }

  // ──────────── Save ────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final out = _line.copyWith(
      reference: _refCtl.text.trim().isEmpty ? null : _refCtl.text.trim(),
      clearReference: _refCtl.text.trim().isEmpty,
    );
    Navigator.of(context).pop(out);
  }

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_line.acName ?? 'Estimate Line'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Done'),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Materials (${_line.materialDetails.length})'),
            Tab(text: 'Labour (${_line.labourDetails.length})'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_buildMaterialTab(), _buildLabourTab()],
              ),
            ),
            _buildTotalsBar(),
          ],
        ),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) {
          final isMat = _tabs.index == 0;
          return FloatingActionButton.extended(
            onPressed: isMat ? _addMaterialDetail : _addLabourDetail,
            icon: const Icon(Icons.add),
            label: Text(isMat ? 'Add Material' : 'Add Labour'),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _refCtl,
            decoration: const InputDecoration(
              labelText: 'Ref Code',
              hintText: 'e.g. P1/Sr1(A)',
            ),
          ),
          const SizedBox(height: 12),
          // Dimensions: L, B, (H if cuft)
          _DimensionRow(
            label: 'L',
            ft: _line.lengthFt,
            inch: _line.lengthIn,
            onChanged: (ft, inch) => _patchLine(
              (l) => l.copyWith(lengthFt: ft, lengthIn: inch),
            ),
          ),
          const SizedBox(height: 8),
          _DimensionRow(
            label: 'B',
            ft: _line.breadthFt,
            inch: _line.breadthIn,
            onChanged: (ft, inch) => _patchLine(
              (l) => l.copyWith(breadthFt: ft, breadthIn: inch),
            ),
          ),
          if (_line.measurementType == MeasurementType.cuft) ...[
            const SizedBox(height: 8),
            _DimensionRow(
              label: 'H',
              ft: _line.heightFt,
              inch: _line.heightIn,
              onChanged: (ft, inch) => _patchLine(
                (l) => l.copyWith(heightFt: ft, heightIn: inch),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Manual Qty + Computed display
          Row(
            children: [
              Expanded(
                flex: 2,
                child: NumericField(
                  label: 'Manual Qty (override)',
                  value: _line.manualQty == 0 ? null : _line.manualQty,
                  decimalPlaces: 4,
                  onChanged: (v) =>
                      _patchLine((l) => l.copyWith(manualQty: v ?? 0)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'BASE QTY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatNumber(_line.baseQty, decimals: 2)} '
                        '${_line.uomName ?? _line.measurementType.label.split(" ").first}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialTab() {
    if (_line.materialDetails.isEmpty) {
      return _emptyTab(
        icon: Icons.inventory_2_outlined,
        message: 'No material details',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: _line.materialDetails.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = _line.materialDetails[i];
        return _DetailCard(
          icon: Icons.inventory_2_outlined,
          title: d.materialName ?? 'Material #${d.materialId}',
          uomName: d.uomName,
          suggestedQty: d.suggestedQty,
          quantity: d.quantity,
          rate: d.rate,
          per: d.per,
          amount: d.amount,
          isManual: d.isManual,
          onEdit: () async {
            final updated = await _editDetailDialog<EstimateLineMaterial>(
              title: d.materialName ?? 'Material',
              subtitle: d.uomName,
              initial: d,
              suggestedQty: d.suggestedQty,
              copyWith: (qty, rate, per, isManual) => d.copyWith(
                quantity: qty,
                rate: rate,
                per: per,
                isManual: isManual,
              ),
            );
            if (updated != null) _replaceMaterial(i, updated);
          },
          onDelete: () => _removeMaterial(i),
        );
      },
    );
  }

  Widget _buildLabourTab() {
    if (_line.labourDetails.isEmpty) {
      return _emptyTab(
        icon: Icons.engineering_outlined,
        message: 'No labour details',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
      itemCount: _line.labourDetails.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final d = _line.labourDetails[i];
        return _DetailCard(
          icon: Icons.engineering_outlined,
          title: d.labourName ?? 'Labour #${d.labourId}',
          uomName: d.uomName,
          suggestedQty: d.suggestedQty,
          quantity: d.quantity,
          rate: d.rate,
          per: d.per,
          amount: d.amount,
          isManual: d.isManual,
          onEdit: () async {
            final updated = await _editDetailDialog<EstimateLineLabour>(
              title: d.labourName ?? 'Labour',
              subtitle: d.uomName,
              initial: d,
              suggestedQty: d.suggestedQty,
              copyWith: (qty, rate, per, isManual) => d.copyWith(
                quantity: qty,
                rate: rate,
                per: per,
                isManual: isManual,
              ),
            );
            if (updated != null) _replaceLabour(i, updated);
          },
          onDelete: () => _removeLabour(i),
        );
      },
    );
  }

  Widget _emptyTab({required IconData icon, required String message}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTotalsBar() {
    final scheme = Theme.of(context).colorScheme;
    return flutter.Material(
      elevation: 4,
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _Totals(
                  label: 'Material',
                  value: _line.materialTotal,
                ),
              ),
              Container(width: 1, height: 32, color: scheme.outlineVariant),
              Expanded(
                child: _Totals(label: 'Labour', value: _line.labourTotal),
              ),
              Container(width: 1, height: 32, color: scheme.outlineVariant),
              Expanded(
                child: _Totals(
                  label: 'Line Total',
                  value: _line.totalCost,
                  emphasize: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────── Edit-detail dialog ────────────

  Future<T?> _editDetailDialog<T>({
    required String title,
    String? subtitle,
    required dynamic initial,
    required double suggestedQty,
    required T Function(double qty, double rate, double per, bool isManual)
        copyWith,
  }) {
    return showDialog<T>(
      context: context,
      builder: (_) => _DetailEditDialog<T>(
        title: title,
        subtitle: subtitle,
        suggestedQty: suggestedQty,
        initialQty: initial.quantity as double,
        initialRate: initial.rate as double,
        initialPer: initial.per as double,
        initialIsManual: initial.isManual as bool,
        copyWith: copyWith,
      ),
    );
  }
}

// ──────────────── Dimension input row ────────────────

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.label,
    required this.ft,
    required this.inch,
    required this.onChanged,
  });

  final String label;
  final double ft;
  final double inch;
  final void Function(double ft, double inch) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: NumericField(
            label: 'Ft',
            value: ft == 0 ? null : ft,
            decimalPlaces: 4,
            onChanged: (v) => onChanged(v ?? 0, inch),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: NumericField(
            label: 'In',
            value: inch == 0 ? null : inch,
            decimalPlaces: 4,
            min: 0,
            max: 11.99,
            onChanged: (v) => onChanged(ft, v ?? 0),
          ),
        ),
      ],
    );
  }
}

// ──────────────── Detail card ────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.uomName,
    required this.suggestedQty,
    required this.quantity,
    required this.rate,
    required this.per,
    required this.amount,
    required this.isManual,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String? uomName;
  final double suggestedQty;
  final double quantity;
  final double rate;
  final double per;
  final double amount;
  final bool isManual;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(icon, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    formatCurrency(amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 36, right: 12),
                child: Row(
                  children: [
                    if (isManual)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'MANUAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      )
                    else
                      Text(
                        'auto',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formatNumber(quantity, decimals: 2)} '
                        '${uomName ?? ''} × ${formatCurrency(rate)}'
                        '${per != 1 ? ' / ${per.toStringAsFixed(0)}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────── Detail edit dialog ────────────────

class _DetailEditDialog<T> extends StatefulWidget {
  const _DetailEditDialog({
    required this.title,
    this.subtitle,
    required this.suggestedQty,
    required this.initialQty,
    required this.initialRate,
    required this.initialPer,
    required this.initialIsManual,
    required this.copyWith,
  });

  final String title;
  final String? subtitle;
  final double suggestedQty;
  final double initialQty;
  final double initialRate;
  final double initialPer;
  final bool initialIsManual;
  final T Function(double qty, double rate, double per, bool isManual)
      copyWith;

  @override
  State<_DetailEditDialog<T>> createState() => _DetailEditDialogState<T>();
}

class _DetailEditDialogState<T> extends State<_DetailEditDialog<T>> {
  late double? _qty = widget.initialQty == 0 ? null : widget.initialQty;
  late double? _rate = widget.initialRate;
  late double? _per = widget.initialPer;
  late bool _isManual = widget.initialIsManual;

  double get _amount {
    final q = _qty ?? 0;
    final r = _rate ?? 0;
    final p = (_per == null || _per == 0) ? 1.0 : _per!;
    return (q * r) / p;
  }

  void _resetToSuggested() {
    setState(() {
      _isManual = false;
      _qty = widget.suggestedQty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 18)),
          if (widget.subtitle != null)
            Text(
              'per ${widget.subtitle}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Suggested: ${formatNumber(widget.suggestedQty, decimals: 4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _resetToSuggested,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NumericField(
              label: 'Quantity',
              value: _qty,
              decimalPlaces: 4,
              required: true,
              onChanged: (v) => setState(() {
                _qty = v;
                if (v != null && (v - widget.suggestedQty).abs() > 1e-6) {
                  _isManual = true;
                }
              }),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Manual override'),
              subtitle: Text(
                _isManual
                    ? 'Quantity ကို override လုပ်ထား'
                    : 'Suggested ကို auto-track လုပ်နေ',
                style: const TextStyle(fontSize: 11),
              ),
              value: _isManual,
              dense: true,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() {
                _isManual = v;
                if (!v) _qty = widget.suggestedQty;
              }),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: NumericField(
                    label: 'Rate',
                    value: _rate,
                    decimalPlaces: 4,
                    currency: true,
                    onChanged: (v) => setState(() => _rate = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: NumericField(
                    label: 'Per',
                    value: _per,
                    decimalPlaces: 4,
                    onChanged: (v) => setState(() => _per = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Amount: '),
                Text(
                  formatCurrency(_amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            widget.copyWith(
              _qty ?? 0,
              _rate ?? 0,
              _per ?? 1,
              _isManual,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ──────────────── Reused widgets ────────────────

class _Totals extends StatelessWidget {
  const _Totals({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          formatCurrency(value),
          style: TextStyle(
            fontSize: emphasize ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: emphasize ? scheme.primary : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _GenericPickerSheet<T> extends StatefulWidget {
  const _GenericPickerSheet({
    required this.label,
    required this.searchItems,
    required this.itemId,
    required this.itemLabel,
    this.itemSubtitle,
  });

  final String label;
  final Future<List<T>> Function(String query) searchItems;
  final int Function(T item) itemId;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;

  @override
  State<_GenericPickerSheet<T>> createState() =>
      _GenericPickerSheetState<T>();
}

class _GenericPickerSheetState<T> extends State<_GenericPickerSheet<T>> {
  final _searchCtl = TextEditingController();
  List<T> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    setState(() => _loading = true);
    final items = await widget.searchItems(q);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select ${widget.label}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtl,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search…',
                ),
                onChanged: _runSearch,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('No results'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final item = _items[i];
                            return ListTile(
                              title: Text(widget.itemLabel(item)),
                              subtitle: widget.itemSubtitle != null
                                  ? Text(widget.itemSubtitle!(item))
                                  : null,
                              onTap: () => Navigator.of(context).pop(item),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
