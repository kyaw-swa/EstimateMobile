import 'package:flutter/material.dart' hide Material;
import 'package:flutter/material.dart' as flutter show Material;

import '../../models/abstract_of_cost.dart';
import '../../models/labour.dart';
import '../../models/material.dart';
import '../../models/uom.dart';
import '../../repositories/abstract_of_cost_repository.dart';
import '../../repositories/labour_repository.dart';
import '../../repositories/material_repository.dart';
import '../../repositories/uom_repository.dart';
import '../../widgets/many2one_picker.dart';
import '../../widgets/numeric_field.dart';
import '../../widgets/selection_dropdown.dart';

class AcFormScreen extends StatefulWidget {
  const AcFormScreen({
    super.key,
    required this.repository,
    this.acId,
    this.uomRepository,
    this.materialRepository,
    this.labourRepository,
  });

  final AbstractOfCostRepository repository;
  final UomRepository? uomRepository;
  final MaterialRepository? materialRepository;
  final LabourRepository? labourRepository;

  /// Null = create mode; non-null = edit mode (loaded by id).
  final int? acId;

  @override
  State<AcFormScreen> createState() => _AcFormScreenState();
}

class _AcFormScreenState extends State<AcFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();

  late final UomRepository _uomRepo = widget.uomRepository ?? UomRepository();
  late final MaterialRepository _matRepo =
      widget.materialRepository ?? MaterialRepository();
  late final LabourRepository _labRepo =
      widget.labourRepository ?? LabourRepository();

  // Header fields
  double? _baseQuantity = 1;
  int? _baseUomId;
  String? _baseUomName;
  MeasurementType _measurementType = MeasurementType.sqft;
  bool _active = true;

  // Lines
  List<AcMaterialLine> _materialLines = [];
  List<AcLabourLine> _labourLines = [];

  // Loaded id (null until loaded in edit mode)
  int? _id;

  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.acId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loading = true;
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final loaded = await widget.repository.findById(widget.acId!);
    if (!mounted) return;
    if (loaded == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _id = loaded.id;
      _nameCtl.text = loaded.name;
      _descCtl.text = loaded.description ?? '';
      _baseQuantity = loaded.baseQuantity;
      _baseUomId = loaded.baseUomId;
      _baseUomName = loaded.baseUomName;
      _measurementType = loaded.measurementType;
      _active = loaded.active;
      _materialLines = List.of(loaded.materialLines);
      _labourLines = List.of(loaded.labourLines);
      _loading = false;
    });
  }

  // ──────────── Pickers ────────────

  Future<List<UnitOfMeasure>> _searchAllUoms(String q) =>
      _uomRepo.findAll(activeOnly: true, search: q);

  Future<List<Material>> _searchMaterials(String q) =>
      _matRepo.findAll(activeOnly: true, search: q);

  Future<List<Labour>> _searchLabours(String q) =>
      _labRepo.findAll(activeOnly: true, search: q);

  // ──────────── Line operations ────────────

  Future<void> _addMaterialLine() async {
    final material = await _pickMaterial();
    if (material == null) return;
    setState(() {
      _materialLines = [
        ..._materialLines,
        AcMaterialLine(
          materialId: material.id!,
          materialName: material.name,
          uomName: material.uomName,
          sequence: (_materialLines.length + 1) * 10,
          quantity: 1,
          rate: material.defaultRate,
        ),
      ];
    });
  }

  Future<Material?> _pickMaterial() async {
    final taken = _materialLines.map((l) => l.materialId).toSet();
    Future<List<Material>> filteredSearch(String q) async {
      final all = await _searchMaterials(q);
      return all.where((m) => !taken.contains(m.id)).toList();
    }

    return showModalBottomSheet<Material>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet<Material>(
        label: 'Material',
        searchItems: filteredSearch,
        itemId: (m) => m.id!,
        itemLabel: (m) => m.name,
        itemSubtitle: (m) =>
            m.uomName != null ? 'per ${m.uomName}' : 'no UoM',
      ),
    );
  }

  void _editMaterialLine(int index, AcMaterialLine updated) {
    setState(() {
      final list = [..._materialLines];
      list[index] = updated;
      _materialLines = list;
    });
  }

  void _removeMaterialLine(int index) {
    setState(() {
      _materialLines = [..._materialLines]..removeAt(index);
    });
  }

  Future<void> _addLabourLine() async {
    final labour = await _pickLabour();
    if (labour == null) return;
    setState(() {
      _labourLines = [
        ..._labourLines,
        AcLabourLine(
          labourId: labour.id!,
          labourName: labour.name,
          uomName: labour.uomName,
          sequence: (_labourLines.length + 1) * 10,
          quantity: 1,
          rate: labour.defaultRate,
        ),
      ];
    });
  }

  Future<Labour?> _pickLabour() async {
    final taken = _labourLines.map((l) => l.labourId).toSet();
    Future<List<Labour>> filteredSearch(String q) async {
      final all = await _searchLabours(q);
      return all.where((l) => !taken.contains(l.id)).toList();
    }

    return showModalBottomSheet<Labour>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet<Labour>(
        label: 'Labour',
        searchItems: filteredSearch,
        itemId: (l) => l.id!,
        itemLabel: (l) => l.name,
        itemSubtitle: (l) =>
            l.uomName != null ? 'per ${l.uomName}' : 'no UoM',
      ),
    );
  }

  void _editLabourLine(int index, AcLabourLine updated) {
    setState(() {
      final list = [..._labourLines];
      list[index] = updated;
      _labourLines = list;
    });
  }

  void _removeLabourLine(int index) {
    setState(() {
      _labourLines = [..._labourLines]..removeAt(index);
    });
  }

  // ──────────── Save ────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final ac = AbstractOfCost(
      id: _id,
      name: _nameCtl.text.trim(),
      description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
      baseQuantity: _baseQuantity ?? 1,
      baseUomId: _baseUomId,
      measurementType: _measurementType,
      active: _active,
      materialLines: _materialLines,
      labourLines: _labourLines,
    );

    try {
      await widget.repository.save(ac);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  // ──────────── Build ────────────

  double get _materialCost =>
      _materialLines.fold(0, (s, l) => s + l.lineCost);
  double get _labourCost => _labourLines.fold(0, (s, l) => s + l.lineCost);
  double get _totalCost => _materialCost + _labourCost;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit A/C' : 'New A/C'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _buildHeaderFields(),
                  const SizedBox(height: 20),
                  _buildMaterialsSection(),
                  const SizedBox(height: 20),
                  _buildLaboursSection(),
                ],
              ),
            ),
            _buildTotalsBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nameCtl,
          autofocus: !_isEdit,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Name *',
            hintText: 'e.g. RC slab 4" thk per 1000 Sqft',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name လိုအပ်ပါတယ်' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: NumericField(
                label: 'Base Qty',
                value: _baseQuantity,
                decimalPlaces: 4,
                required: true,
                onChanged: (v) => _baseQuantity = v,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Many2onePicker<UnitOfMeasure>(
                label: 'Base UoM',
                selectedId: _baseUomId,
                displayText: _baseUomName,
                searchItems: _searchAllUoms,
                itemId: (u) => u.id!,
                itemLabel: (u) => u.name,
                itemSubtitle: (u) => u.uomType.label,
                onChanged: (id, item) => setState(() {
                  _baseUomId = id;
                  _baseUomName = item?.name;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectionDropdown<MeasurementType>(
          label: 'Measurement Type',
          required: true,
          value: _measurementType,
          values: MeasurementType.values,
          labelOf: (t) => t.label,
          iconOf: (t) => t == MeasurementType.sqft
              ? Icons.crop_square
              : Icons.view_in_ar_outlined,
          onChanged: (v) {
            if (v != null) setState(() => _measurementType = v);
          },
        ),
      ],
    );
  }

  Widget _buildMaterialsSection() {
    return _LineSection(
      icon: Icons.inventory_2_outlined,
      title: 'Materials',
      count: _materialLines.length,
      onAdd: _addMaterialLine,
      addLabel: 'Add Material',
      emptyMessage: 'Material line မရှိသေးပါ',
      children: [
        for (var i = 0; i < _materialLines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _MaterialLineCard(
              line: _materialLines[i],
              onEdit: () async {
                final updated = await _editMaterialDialog(_materialLines[i]);
                if (updated != null) _editMaterialLine(i, updated);
              },
              onDelete: () => _removeMaterialLine(i),
            ),
          ),
      ],
    );
  }

  Widget _buildLaboursSection() {
    return _LineSection(
      icon: Icons.engineering_outlined,
      title: 'Labours',
      count: _labourLines.length,
      onAdd: _addLabourLine,
      addLabel: 'Add Labour',
      emptyMessage: 'Labour line မရှိသေးပါ',
      children: [
        for (var i = 0; i < _labourLines.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LabourLineCard(
              line: _labourLines[i],
              onEdit: () async {
                final updated = await _editLabourDialog(_labourLines[i]);
                if (updated != null) _editLabourLine(i, updated);
              },
              onDelete: () => _removeLabourLine(i),
            ),
          ),
      ],
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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Totals(label: 'Material', value: _materialCost),
              Divider(height: 10, color: scheme.outlineVariant),
              _Totals(label: 'Labour', value: _labourCost),
              Divider(height: 10, color: scheme.outlineVariant),
              _Totals(
                label: 'Total',
                value: _totalCost,
                emphasize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────── Inline edit dialogs ────────────

  Future<AcMaterialLine?> _editMaterialDialog(AcMaterialLine line) {
    return showDialog<AcMaterialLine>(
      context: context,
      builder: (_) => _LineEditDialog(
        title: line.materialName ?? 'Material line',
        subtitle: line.uomName != null ? 'per ${line.uomName}' : null,
        initialQuantity: line.quantity,
        initialRate: line.rate,
        onSave: (qty, rate) =>
            line.copyWith(quantity: qty, rate: rate),
      ),
    );
  }

  Future<AcLabourLine?> _editLabourDialog(AcLabourLine line) {
    return showDialog<AcLabourLine>(
      context: context,
      builder: (_) => _LineEditDialog<AcLabourLine>(
        title: line.labourName ?? 'Labour line',
        subtitle: line.uomName != null ? 'per ${line.uomName}' : null,
        initialQuantity: line.quantity,
        initialRate: line.rate,
        onSave: (qty, rate) =>
            line.copyWith(quantity: qty, rate: rate),
      ),
    );
  }
}

// ──────────────── Line section (header + add + cards or empty) ────────────────

class _LineSection extends StatelessWidget {
  const _LineSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.onAdd,
    required this.addLabel,
    required this.emptyMessage,
    required this.children,
  });

  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onAdd;
  final String addLabel;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              '${title.toUpperCase()} ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: scheme.primary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

// ──────────────── Line cards ────────────────

class _MaterialLineCard extends StatelessWidget {
  const _MaterialLineCard({
    required this.line,
    required this.onEdit,
    required this.onDelete,
  });

  final AcMaterialLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _LineCard(
      icon: Icons.inventory_2_outlined,
      title: line.materialName ?? 'Material #${line.materialId}',
      uomName: line.uomName,
      quantity: line.quantity,
      rate: line.rate,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _LabourLineCard extends StatelessWidget {
  const _LabourLineCard({
    required this.line,
    required this.onEdit,
    required this.onDelete,
  });

  final AcLabourLine line;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return _LineCard(
      icon: Icons.engineering_outlined,
      title: line.labourName ?? 'Labour #${line.labourId}',
      uomName: line.uomName,
      quantity: line.quantity,
      rate: line.rate,
      onEdit: onEdit,
      onDelete: onDelete,
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.icon,
    required this.title,
    required this.uomName,
    required this.quantity,
    required this.rate,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final String title;
  final String? uomName;
  final double quantity;
  final double rate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cost = quantity * rate;
    return Card(
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              Icon(icon, color: scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatNumber(quantity, decimals: 2)} '
                      '${uomName ?? ''} × ${formatCurrency(rate)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(cost),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    onPressed: onDelete,
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: emphasize ? 12 : 11,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
              color: emphasize ? scheme.primary : scheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Text(
          formatCurrency(value),
          style: TextStyle(
            fontSize: emphasize ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: emphasize ? scheme.primary : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ──────────────── Line edit dialog ────────────────

class _LineEditDialog<T> extends StatefulWidget {
  const _LineEditDialog({
    required this.title,
    this.subtitle,
    required this.initialQuantity,
    required this.initialRate,
    required this.onSave,
  });

  final String title;
  final String? subtitle;
  final double initialQuantity;
  final double initialRate;
  final T Function(double quantity, double rate) onSave;

  @override
  State<_LineEditDialog<T>> createState() => _LineEditDialogState<T>();
}

class _LineEditDialogState<T> extends State<_LineEditDialog<T>> {
  late double? _qty = widget.initialQuantity;
  late double? _rate = widget.initialRate;

  double get _cost => (_qty ?? 0) * (_rate ?? 0);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontSize: 18)),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NumericField(
            label: 'Std. Quantity',
            value: _qty,
            decimalPlaces: 4,
            required: true,
            onChanged: (v) => setState(() => _qty = v),
          ),
          const SizedBox(height: 12),
          NumericField(
            label: 'Rate',
            value: _rate,
            decimalPlaces: 4,
            currency: true,
            onChanged: (v) => setState(() => _rate = v),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Line cost: '),
              Text(
                formatCurrency(_cost),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            widget.onSave(_qty ?? 0, _rate ?? 0),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ──────────────── Picker sheet (similar to Many2one but standalone) ────────────────

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
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
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
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
