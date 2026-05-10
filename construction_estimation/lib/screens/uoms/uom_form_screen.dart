import 'package:flutter/material.dart';

import '../../models/uom.dart';
import '../../repositories/uom_repository.dart';
import '../../widgets/selection_dropdown.dart';

class UomFormScreen extends StatefulWidget {
  const UomFormScreen({
    super.key,
    required this.repository,
    this.uom,
  });

  final UomRepository repository;

  /// Null = create mode; non-null = edit mode.
  final UnitOfMeasure? uom;

  @override
  State<UomFormScreen> createState() => _UomFormScreenState();
}

class _UomFormScreenState extends State<UomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();

  late UomType _uomType;
  late bool _active;
  bool _saving = false;
  String? _nameError;

  bool get _isEdit => widget.uom != null;

  @override
  void initState() {
    super.initState();
    final u = widget.uom;
    _nameCtl.text = u?.name ?? '';
    _uomType = u?.uomType ?? UomType.both;
    _active = u?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _nameError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final now = DateTime.now();
    final uom = (widget.uom ??
            UnitOfMeasure(
              name: _nameCtl.text.trim(),
              uomType: _uomType,
              active: _active,
            ))
        .copyWith(
      name: _nameCtl.text.trim(),
      uomType: _uomType,
      active: _active,
      updatedAt: now,
    );

    try {
      await widget.repository.save(uom);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // UNIQUE constraint on `name` — surface as field error.
        if (e.toString().toLowerCase().contains('unique')) {
          _nameError = 'ဒီနာမည်နဲ့ UoM ရှိပြီးသား';
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
        title: Text(_isEdit ? 'Edit UoM' : 'New UoM'),
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
                hintText: 'e.g. Bags, Cuft, Man-days',
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
            SelectionDropdown<UomType>(
              label: 'Type',
              required: true,
              value: _uomType,
              values: UomType.values,
              labelOf: (t) => t.label,
              iconOf: (t) => switch (t) {
                UomType.material => Icons.inventory_2_outlined,
                UomType.labour => Icons.engineering_outlined,
                UomType.both => Icons.swap_horiz,
              },
              onChanged: (v) {
                if (v != null) setState(() => _uomType = v);
              },
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
