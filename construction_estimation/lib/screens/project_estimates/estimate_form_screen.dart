import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/abstract_of_cost.dart';
import '../../models/project_estimate.dart';
import '../../repositories/abstract_of_cost_repository.dart';
import '../../repositories/project_estimate_repository.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/numeric_field.dart';
import 'estimate_line_form_screen.dart';

class EstimateFormScreen extends StatefulWidget {
  const EstimateFormScreen({
    super.key,
    required this.repository,
    this.acRepository,
    this.estimateId,
  });

  final ProjectEstimateRepository repository;
  final AbstractOfCostRepository? acRepository;

  /// Null = create mode; non-null = edit mode (loaded by id).
  final int? estimateId;

  @override
  State<EstimateFormScreen> createState() => _EstimateFormScreenState();
}

class _EstimateFormScreenState extends State<EstimateFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _customerCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  late final AbstractOfCostRepository _acRepo =
      widget.acRepository ?? AbstractOfCostRepository();

  int? _id;
  DateTime? _date = DateTime.now();
  EstimateState _state = EstimateState.draft;
  List<EstimateLine> _lines = [];

  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.estimateId != null;

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
    _customerCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    final loaded = await widget.repository.findById(widget.estimateId!);
    if (!mounted) return;
    if (loaded == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _id = loaded.id;
      _nameCtl.text = loaded.name;
      _customerCtl.text = loaded.customerName ?? '';
      _notesCtl.text = loaded.notes ?? '';
      _date = loaded.date;
      _state = loaded.state;
      _lines = List.of(loaded.lines);
      _loading = false;
    });
  }

  // ──────────── Line ops ────────────

  Future<void> _addLine() async {
    // Step 1: pick AC.
    final ac = await _pickAc();
    if (ac == null) return;
    if (!mounted) return;

    // Step 2: load full AC (with material/labour template lines).
    final fullAc = await _acRepo.findById(ac.id!);
    if (fullAc == null) return;
    if (!mounted) return;

    // Step 3: build a new EstimateLine seeded from the AC template.
    final newLine = _seedLineFromAc(fullAc);

    // Step 4: open the line form for further editing.
    final result = await Navigator.of(context).push<EstimateLine?>(
      MaterialPageRoute(
        builder: (_) => EstimateLineFormScreen(initialLine: newLine),
      ),
    );
    if (result == null) return;
    setState(() {
      _lines = [..._lines, result];
    });
  }

  EstimateLine _seedLineFromAc(AbstractOfCost ac) {
    final templateBase = ac.baseQuantity == 0 ? 1.0 : ac.baseQuantity;
    return EstimateLine(
      acId: ac.id!,
      acName: ac.name,
      baseUomName: ac.baseUomName,
      sequence: (_lines.length + 1) * 10,
      measurementType: ac.measurementType,
      uomId: ac.baseUomId,
      uomName: ac.baseUomName,
      materialDetails: [
        for (final ml in ac.materialLines)
          EstimateLineMaterial(
            materialId: ml.materialId,
            materialName: ml.materialName,
            uomName: ml.uomName,
            sequence: ml.sequence,
            templateQty: ml.quantity,
            templateBaseQty: templateBase,
            rate: ml.rate,
            // quantity will be synced to suggestedQty on save
          ),
      ],
      labourDetails: [
        for (final ll in ac.labourLines)
          EstimateLineLabour(
            labourId: ll.labourId,
            labourName: ll.labourName,
            uomName: ll.uomName,
            sequence: ll.sequence,
            templateQty: ll.quantity,
            templateBaseQty: templateBase,
            rate: ll.rate,
          ),
      ],
    );
  }

  Future<AbstractOfCost?> _pickAc() async {
    return showModalBottomSheet<AbstractOfCost>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AcPickerSheet(
        searchItems: (q) => _acRepo.findAll(activeOnly: true, search: q),
      ),
    );
  }

  Future<void> _editLine(int index) async {
    final result = await Navigator.of(context).push<EstimateLine?>(
      MaterialPageRoute(
        builder: (_) => EstimateLineFormScreen(initialLine: _lines[index]),
      ),
    );
    if (result == null) return;
    setState(() {
      final list = [..._lines];
      list[index] = result;
      _lines = list;
    });
  }

  Future<void> _removeLine(int index) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'Remove line?',
      message: 'ဒီ line နဲ့ ၎င်းရဲ့ material/labour details တွေ ပြန်မရတော့ပါ။',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok) return;
    setState(() {
      _lines = [..._lines]..removeAt(index);
    });
  }

  // ──────────── Save / state actions ────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final estimate = ProjectEstimate(
      id: _id,
      name: _nameCtl.text.trim(),
      customerName:
          _customerCtl.text.trim().isEmpty ? null : _customerCtl.text.trim(),
      date: _date,
      state: _state,
      notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      lines: _lines,
    );

    try {
      final saved = await widget.repository.save(estimate);
      _id = saved;
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

  Future<void> _changeState(EstimateState target) async {
    setState(() => _state = target);
  }

  // ──────────── Build ────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final materialCost = _lines.fold<double>(0, (s, l) => s + l.materialTotal);
    final labourCost = _lines.fold<double>(0, (s, l) => s + l.labourTotal);
    final grandTotal = materialCost + labourCost;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Estimate' : 'New Estimate'),
        actions: [
          PopupMenuButton<EstimateState>(
            icon: const Icon(Icons.flag_outlined),
            tooltip: 'Change state',
            onSelected: _changeState,
            itemBuilder: (_) => [
              for (final s in EstimateState.values)
                PopupMenuItem(
                  value: s,
                  enabled: _state != s,
                  child: ListTile(
                    leading: Icon(_stateIcon(s)),
                    title: Text(s.label),
                    selected: _state == s,
                    dense: true,
                  ),
                ),
            ],
          ),
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
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  _buildLinesSection(),
                ],
              ),
            ),
            _buildTotalsBar(materialCost, labourCost, grandTotal),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLine,
        icon: const Icon(Icons.add),
        label: const Text('Add Line'),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ESTIMATE DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: scheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _stateBg(scheme),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_stateIcon(_state), size: 14, color: _stateFg(scheme)),
                  const SizedBox(width: 4),
                  Text(
                    _state.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _stateFg(scheme),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameCtl,
          autofocus: !_isEdit,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Estimate Name *',
            hintText: 'e.g. Two-storey building, Yangon',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Name လိုအပ်ပါတယ်' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customerCtl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Customer',
            hintText: 'Customer name',
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDate,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date',
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            child: Text(
              _date != null
                  ? DateFormat('d MMM yyyy').format(_date!)
                  : 'No date',
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesCtl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Widget _buildLinesSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'WORK ITEMS (${_lines.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: scheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_lines.isEmpty)
          _emptyLines()
        else
          ..._lines.asMap().entries.map((entry) {
            final i = entry.key;
            final line = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LineCard(
                line: line,
                onTap: () => _editLine(i),
                onDelete: () => _removeLine(i),
              ),
            );
          }),
      ],
    );
  }

  Widget _emptyLines() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 36,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'No work items yet',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          Text(
            'Tap + to add an A/C work item',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsBar(double mat, double lab, double total) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 4,
      color: scheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(child: _Totals(label: 'Material', value: mat)),
              Container(width: 1, height: 32, color: scheme.outlineVariant),
              Expanded(child: _Totals(label: 'Labour', value: lab)),
              Container(width: 1, height: 32, color: scheme.outlineVariant),
              Expanded(
                child: _Totals(label: 'Total', value: total, emphasize: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _stateIcon(EstimateState s) => switch (s) {
        EstimateState.draft => Icons.edit_note_outlined,
        EstimateState.confirmed => Icons.check_circle_outline,
        EstimateState.cancelled => Icons.cancel_outlined,
      };

  Color _stateBg(ColorScheme scheme) => switch (_state) {
        EstimateState.draft => scheme.surfaceContainerHighest,
        EstimateState.confirmed => scheme.primaryContainer,
        EstimateState.cancelled => scheme.errorContainer,
      };

  Color _stateFg(ColorScheme scheme) => switch (_state) {
        EstimateState.draft => scheme.onSurfaceVariant,
        EstimateState.confirmed => scheme.onPrimaryContainer,
        EstimateState.cancelled => scheme.onErrorContainer,
      };
}

// ──────────────── Line card ────────────────

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.onTap,
    required this.onDelete,
  });

  final EstimateLine line;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dimsLabel = _dimsLabel(line);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.calculate_outlined,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (line.reference != null && line.reference!.isNotEmpty)
                      Text(
                        line.reference!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: scheme.tertiary,
                        ),
                      ),
                    Text(
                      line.acName ?? 'AC #${line.acId}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (dimsLabel != null)
                          _MiniChip(icon: Icons.straighten, label: dimsLabel),
                        _MiniChip(
                          icon: Icons.functions,
                          label:
                              '${formatNumber(line.baseQty, decimals: 2)} '
                              '${line.uomName ?? line.measurementType.label.split(" ").first}',
                        ),
                        _MiniChip(
                          icon: Icons.inventory_2_outlined,
                          label:
                              '${line.materialDetails.length} mat',
                        ),
                        _MiniChip(
                          icon: Icons.engineering_outlined,
                          label: '${line.labourDetails.length} lab',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(line.totalCost),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: scheme.error),
                    tooltip: 'Remove',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _dimsLabel(EstimateLine l) {
    String fmt(double ft, double inch) {
      if (ft == 0 && inch == 0) return '';
      if (inch == 0) return "${ft.toStringAsFixed(0)}'";
      if (ft == 0) return '${inch.toStringAsFixed(0)}"';
      return "${ft.toStringAsFixed(0)}'${inch.toStringAsFixed(0)}\"";
    }

    final lFt = fmt(l.lengthFt, l.lengthIn);
    final bFt = fmt(l.breadthFt, l.breadthIn);
    final hFt = fmt(l.heightFt, l.heightIn);

    final parts = <String>[];
    if (lFt.isNotEmpty) parts.add(lFt);
    if (bFt.isNotEmpty) parts.add(bFt);
    if (l.measurementType == MeasurementType.cuft && hFt.isNotEmpty) {
      parts.add(hFt);
    }
    if (parts.isEmpty) return null;
    return parts.join(' × ');
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: scheme.onSurfaceVariant),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurface),
          ),
        ],
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

// ──────────────── AC picker sheet ────────────────

class _AcPickerSheet extends StatefulWidget {
  const _AcPickerSheet({required this.searchItems});

  final Future<List<AbstractOfCost>> Function(String query) searchItems;

  @override
  State<_AcPickerSheet> createState() => _AcPickerSheetState();
}

class _AcPickerSheetState extends State<_AcPickerSheet> {
  final _searchCtl = TextEditingController();
  List<AbstractOfCost> _items = const [];
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
                      'Select Work Item (A/C)',
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
                  hintText: 'Search A/C…',
                ),
                onChanged: _runSearch,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? const Center(child: Text('No A/C templates found'))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final ac = _items[i];
                            return ListTile(
                              leading: const Icon(Icons.calculate_outlined),
                              title: Text(ac.name),
                              subtitle: Text(
                                'Per ${ac.baseQuantity.toStringAsFixed(0)} '
                                '${ac.baseUomName ?? ac.measurementType.label}',
                              ),
                              onTap: () => Navigator.of(context).pop(ac),
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
