import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter show Material;

import '../../models/project_estimate.dart';
import '../../widgets/numeric_field.dart';

/// Edit one EstimateLine — dimensions only.
///
/// Material and labour quantities come from the A/C template and are derived
/// from the line's dimensions. There is no manual override on the line, the
/// materials, or the labour details.
///
/// Returns the updated [EstimateLine] (or null if cancelled).
class EstimateLineFormScreen extends StatefulWidget {
  const EstimateLineFormScreen({
    super.key,
    required this.initialLine,
  });

  final EstimateLine initialLine;

  @override
  State<EstimateLineFormScreen> createState() =>
      _EstimateLineFormScreenState();
}

class _EstimateLineFormScreenState extends State<EstimateLineFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _refCtl = TextEditingController();

  late EstimateLine _line;

  @override
  void initState() {
    super.initState();
    _line = widget.initialLine;
    _refCtl.text = _line.reference ?? '';
  }

  @override
  void dispose() {
    _refCtl.dispose();
    super.dispose();
  }

  // ──────────── Mutators (always sync details' parentBaseQty) ────────────

  /// Re-derive the line so detail.parentBaseQty stays current.
  /// Must be called after any dimension change.
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
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
        // Computed Base Qty display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.functions, color: scheme.onPrimaryContainer),
              const SizedBox(width: 10),
              Expanded(
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMaterialsSection() {
    return _LineSection(
      icon: Icons.inventory_2_outlined,
      title: 'Materials',
      count: _line.materialDetails.length,
      emptyMessage: 'A/C template မှာ material မရှိပါ',
      children: [
        for (var i = 0; i < _line.materialDetails.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _detailCardForMaterial(i),
          ),
      ],
    );
  }

  Widget _buildLaboursSection() {
    return _LineSection(
      icon: Icons.engineering_outlined,
      title: 'Labours',
      count: _line.labourDetails.length,
      emptyMessage: 'A/C template မှာ labour မရှိပါ',
      children: [
        for (var i = 0; i < _line.labourDetails.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _detailCardForLabour(i),
          ),
      ],
    );
  }

  Widget _detailCardForMaterial(int i) {
    final d = _line.materialDetails[i];
    return _DetailCard(
      icon: Icons.inventory_2_outlined,
      title: d.materialName ?? 'Material #${d.materialId}',
      uomName: d.uomName,
      quantity: d.suggestedQty,
      rate: d.rate,
      per: d.per,
      amount: d.amount,
    );
  }

  Widget _detailCardForLabour(int i) {
    final d = _line.labourDetails[i];
    return _DetailCard(
      icon: Icons.engineering_outlined,
      title: d.labourName ?? 'Labour #${d.labourId}',
      uomName: d.uomName,
      quantity: d.suggestedQty,
      rate: d.rate,
      per: d.per,
      amount: d.amount,
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
              _Totals(label: 'Material', value: _line.materialTotal),
              Divider(height: 10, color: scheme.outlineVariant),
              _Totals(label: 'Labour', value: _line.labourTotal),
              Divider(height: 10, color: scheme.outlineVariant),
              _Totals(
                label: 'Line Total',
                value: _line.totalCost,
                emphasize: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────── Line section (header + cards or empty) ────────────────

class _LineSection extends StatelessWidget {
  const _LineSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.emptyMessage,
    required this.children,
  });

  final IconData icon;
  final String title;
  final int count;
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

// ──────────────── Detail card (read-only) ────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.uomName,
    required this.quantity,
    required this.rate,
    required this.per,
    required this.amount,
  });

  final IconData icon;
  final String title;
  final String? uomName;
  final double quantity;
  final double rate;
  final double per;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                children: [
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
