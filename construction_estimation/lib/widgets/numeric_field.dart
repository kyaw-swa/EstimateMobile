import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Numeric input — float (decimalPlaces > 0) or integer (decimalPlaces == 0).
///
/// Currency mode သုံးရင် prefix symbol ပြ + display formatting လုပ်.
/// Storage value က [double] (or null when empty)。
class NumericField extends StatefulWidget {
  const NumericField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.decimalPlaces = 2,
    this.currency = false,
    this.currencySymbol = 'K',
    this.min,
    this.max,
    this.hint,
    this.enabled = true,
    this.required = false,
    this.errorText,
    this.allowNegative = false,
  });

  final String label;
  final double? value;
  final void Function(double? value) onChanged;
  final int decimalPlaces;
  final bool currency;
  final String currencySymbol;
  final double? min;
  final double? max;
  final String? hint;
  final bool enabled;
  final bool required;
  final String? errorText;
  final bool allowNegative;

  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(NumericField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final external = _format(widget.value);
    final current = _controller.text;
    final currentParsed = _parse(current);
    if (currentParsed != widget.value && current != external) {
      _controller.text = external;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double? v) {
    if (v == null) return '';
    if (widget.decimalPlaces == 0) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(widget.decimalPlaces);
  }

  double? _parse(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  void _handleChanged(String s) {
    final parsed = _parse(s);
    if (parsed == null && s.trim().isNotEmpty) {
      // Invalid input — don't fire callback yet
      return;
    }
    if (parsed != null) {
      if (widget.min != null && parsed < widget.min!) return;
      if (widget.max != null && parsed > widget.max!) return;
    }
    widget.onChanged(parsed);
  }

  String? _displayPrefix() {
    if (!widget.currency) return null;
    return '${widget.currencySymbol} ';
  }

  @override
  Widget build(BuildContext context) {
    final isInteger = widget.decimalPlaces == 0;
    final regex = isInteger
        ? (widget.allowNegative ? RegExp(r'^-?\d*$') : RegExp(r'^\d*$'))
        : (widget.allowNegative
            ? RegExp(r'^-?\d*\.?\d*$')
            : RegExp(r'^\d*\.?\d*$'));

    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.numberWithOptions(
        decimal: !isInteger,
        signed: widget.allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(regex),
      ],
      decoration: InputDecoration(
        labelText: widget.required ? '${widget.label} *' : widget.label,
        hintText: widget.hint,
        prefixText: _displayPrefix(),
        errorText: widget.errorText,
      ),
      textAlign: TextAlign.end,
      onChanged: _handleChanged,
      onEditingComplete: () {
        // Reformat on commit
        final parsed = _parse(_controller.text);
        _controller.text = _format(parsed);
        widget.onChanged(parsed);
      },
    );
  }
}

/// Currency display helper — read-only display formatting.
String formatCurrency(double? value, {String symbol = 'K', int decimals = 2}) {
  if (value == null) return '';
  final f = NumberFormat.currency(
    symbol: '$symbol ',
    decimalDigits: decimals,
  );
  return f.format(value);
}

/// Number formatter helper — non-currency display.
String formatNumber(double? value, {int decimals = 2}) {
  if (value == null) return '';
  final f = NumberFormat.decimalPatternDigits(decimalDigits: decimals);
  return f.format(value);
}
