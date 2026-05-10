import 'package:flutter/material.dart';

/// Selection field dropdown — Odoo selection field အတွက်.
///
/// Generic `<T>`: enum သုံးရင် ပိုကောင်း (e.g. EstimateState).
/// [values] ထဲက item တစ်ခုကို [labelOf] နဲ့ display လုပ်တယ်.
class SelectionDropdown<T> extends StatelessWidget {
  const SelectionDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
    this.iconOf,
    this.hint,
    this.enabled = true,
    this.required = false,
    this.errorText,
    this.allowClear = false,
  });

  final String label;
  final T? value;
  final List<T> values;
  final String Function(T value) labelOf;
  final IconData? Function(T value)? iconOf;
  final void Function(T? value) onChanged;
  final String? hint;
  final bool enabled;
  final bool required;
  final String? errorText;
  final bool allowClear;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        errorText: errorText,
      ),
      items: [
        if (allowClear)
          const DropdownMenuItem<Never>(
            value: null,
            child: Text('—'),
          ),
        ...values.map((v) {
          final icon = iconOf?.call(v);
          return DropdownMenuItem<T>(
            value: v,
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(labelOf(v)),
              ],
            ),
          );
        }),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}
