import 'dart:async';

import 'package:flutter/material.dart';

/// Many2one picker — Odoo many2one field အတွက် search-as-you-type modal.
///
/// Generic `<T>`: ဘယ် model နဲ့မဆို သုံးနိုင်အောင်။
/// Caller က [searchItems], [itemId], [itemLabel] callback တွေ ပေးရမယ်။
class Many2onePicker<T> extends StatelessWidget {
  const Many2onePicker({
    super.key,
    required this.label,
    required this.selectedId,
    required this.displayText,
    required this.searchItems,
    required this.itemId,
    required this.itemLabel,
    required this.onChanged,
    this.itemSubtitle,
    this.hint,
    this.enabled = true,
    this.required = false,
    this.errorText,
    this.allowClear = true,
  });

  final String label;
  final int? selectedId;
  final String? displayText;
  final String? hint;
  final bool enabled;
  final bool required;
  final String? errorText;
  final bool allowClear;

  /// Search callback — query string ပေးတဲ့အခါ matching items list ပြန်ပေး
  final Future<List<T>> Function(String query) searchItems;
  final int Function(T item) itemId;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;
  final void Function(int? id, T? item) onChanged;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<_PickerResult<T>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _PickerSheet<T>(
        label: label,
        searchItems: searchItems,
        itemId: itemId,
        itemLabel: itemLabel,
        itemSubtitle: itemSubtitle,
        selectedId: selectedId,
      ),
    );
    if (result != null) {
      onChanged(itemId(result.item), result.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = selectedId != null && displayText != null;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        errorText: errorText,
        suffixIcon: hasValue && allowClear && enabled
            ? IconButton(
                icon: const Icon(Icons.clear),
                tooltip: 'Clear',
                onPressed: () => onChanged(null, null),
              )
            : const Icon(Icons.arrow_drop_down),
      ),
      child: InkWell(
        onTap: enabled ? () => _openPicker(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            hasValue ? displayText! : (hint ?? 'Select…'),
            style: hasValue
                ? Theme.of(context).textTheme.bodyLarge
                : Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
          ),
        ),
      ),
    );
  }
}

class _PickerResult<T> {
  const _PickerResult(this.item);
  final T item;
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.label,
    required this.searchItems,
    required this.itemId,
    required this.itemLabel,
    required this.selectedId,
    this.itemSubtitle,
  });

  final String label;
  final Future<List<T>> Function(String query) searchItems;
  final int Function(T item) itemId;
  final String Function(T item) itemLabel;
  final String Function(T item)? itemSubtitle;
  final int? selectedId;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<T> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _runSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.searchItems(query);
      if (!mounted) return;
      setState(() {
        _items = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
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
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search…',
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error: $_error',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No results'));
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = _items[i];
        final id = widget.itemId(item);
        final selected = id == widget.selectedId;
        return ListTile(
          title: Text(widget.itemLabel(item)),
          subtitle: widget.itemSubtitle != null
              ? Text(widget.itemSubtitle!(item))
              : null,
          trailing: selected
              ? Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.primary,
                )
              : null,
          onTap: () => Navigator.of(context).pop(_PickerResult<T>(item)),
        );
      },
    );
  }
}
