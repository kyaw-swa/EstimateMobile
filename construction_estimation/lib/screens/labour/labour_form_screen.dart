import 'package:flutter/material.dart';

import '../../models/labour.dart';
import '../../models/uom.dart';
import '../../repositories/labour_repository.dart';
import '../../repositories/uom_repository.dart';
import '../../widgets/many2one_picker.dart';
import '../../widgets/numeric_field.dart';

class LabourFormScreen extends StatefulWidget {
  const LabourFormScreen({
    super.key,
    required this.repository,
    this.uomRepository,
    this.labour,
  });

  final LabourRepository repository;
  final UomRepository? uomRepository;

  /// Null = create mode; non-null = edit mode.
  final Labour? labour;

  @override
  State<LabourFormScreen> createState() => _LabourFormScreenState();
}

class _LabourFormScreenState extends State<LabourFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();

  late final UomRepository _uomRepo = widget.uomRepository ?? UomRepository();

  int? _uomId;
  String? _uomName;
  double? _defaultRate;
  late bool _active;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.labour != null;

  @override
  void initState() {
    super.initState();
    final l = widget.labour;
    _nameCtl.text = l?.name ?? '';
    _uomId = l?.uomId;
    _uomName = l?.uomName;
    _defaultRate = l?.defaultRate ?? 0;
    _active = l?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  /// UoM picker callback — Odoo domain `uom_type IN ('labour', 'both')`.
  Future<List<UnitOfMeasure>> _searchUoms(String query) {
    return _uomRepo.findAll(
      activeOnly: true,
      type: UomType.labour,
      search: query,
    );
  }

  Future<void> _save() async {
    setState(() => _nameError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final base = widget.labour ??
        Labour(
          name: _nameCtl.text.trim(),
          uomId: _uomId,
          defaultRate: _defaultRate ?? 0,
          active: _active,
        );

    final labour = base.copyWith(
      name: _nameCtl.text.trim(),
      uomId: _uomId,
      clearUomId: _uomId == null,
      defaultRate: _defaultRate ?? 0,
      active: _active,
      updatedAt: DateTime.now(),
    );

    try {
      await widget.repository.save(labour);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (e.toString().toLowerCase().contains('unique')) {
          _nameError = 'ဒီနာမည်နဲ့ labour ရှိပြီးသား';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Save failed: $e')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Labour' : 'New Labour'),
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtl,
              autofocus: !_isEdit,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Name *',
                hintText: 'e.g. Mason, Helper, Steel Fixer',
                errorText: _nameError,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name လိုအပ်ပါတယ်';
                return null;
              },
              onChanged: (_) {
                if (_nameError != null) {
                  setState(() => _nameError = null);
                }
              },
            ),
            const SizedBox(height: 16),
            Many2onePicker<UnitOfMeasure>(
              label: 'Unit of Measure',
              hint: 'Select UoM',
              selectedId: _uomId,
              displayText: _uomName,
              searchItems: _searchUoms,
              itemId: (u) => u.id!,
              itemLabel: (u) => u.name,
              itemSubtitle: (u) => u.uomType.label,
              onChanged: (id, item) => setState(() {
                _uomId = id;
                _uomName = item?.name;
              }),
            ),
            const SizedBox(height: 16),
            NumericField(
              label: 'Default Rate',
              value: _defaultRate,
              decimalPlaces: 4,
              currency: true,
              onChanged: (v) => _defaultRate = v,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Active'),
              subtitle: Text(
                _active
                    ? 'Pickers မှာ ပြမယ်'
                    : 'Archive — pickers မှာ ပုံမှန်အားဖြင့် မပြ',
              ),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      ),
    );
  }
}
