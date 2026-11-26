import "package:flutter/material.dart";
import "package:flutter_blue_max_example/shared/noun.dart";

/// Import/export chooser used by `ParsersPanel` and `CatalogPanel`.
/// Lets the user choose all or some [items], all selected at first.
/// Pops with the chosen items, or with nothing when cancelled.
class const SelectionDialog<T>({
  super.key,
  required final Widget title,

  /// The confirm button, e.g. "Export", followed by the number of chosen items.
  required final String action,

  /// What is chosen.
  required final Noun noun,
  required final List<T> items,
  required final Widget Function(T item) label,
  required final Widget Function(T item) details,
}) extends StatefulWidget {
  static Future<List<T>?> show<T>(
    BuildContext context, {
    required Widget title,
    required String action,
    required Noun noun,
    required List<T> items,
    required Widget Function(T item) label,
    required Widget Function(T item) details,
  }) => showDialog<List<T>>(
    context: context,
    builder: (_) {
      return SelectionDialog(title: title, action: action, noun: noun, items: items, label: label, details: details);
    },
  );

  @override
  State<SelectionDialog<T>> createState() => _SelectionDialogState<T>();
}

class _SelectionDialogState<T>() extends State<SelectionDialog<T>> {
  /// Indices, since equal items can appear twice in a file.
  late final _chosen = {for (var i = 0; i < widget.items.length; i++) i};

  bool? get _allValue {
    if (_chosen.length == widget.items.length) {
      return true;
    }
    if (_chosen.isEmpty) {
      return false;
    }
    return null;
  }

  void _confirmSelection() {
    Navigator.pop(context, [
      for (final (index, item) in widget.items.indexed)
        if (_chosen.contains(index)) item,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final all = _chosen.length == items.length;
    return AlertDialog(
      title: widget.title,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            CheckboxListTile(
              tristate: true,
              value: _allValue,
              title: Text("All ${widget.noun.plural}"),
              onChanged: (_) {
                return setState(() {
                  if (all) {
                    _chosen.clear();
                  } else {
                    _chosen.addAll([for (var i = 0; i < items.length; i++) i]);
                  }
                });
              },
            ),
            const Divider(),
            for (final (index, item) in items.indexed)
              CheckboxListTile(
                value: _chosen.contains(index),
                title: widget.label(item),
                subtitle: widget.details(item),
                onChanged: (value) => setState(() => value! ? _chosen.add(index) : _chosen.remove(index)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        FilledButton(
          onPressed: _chosen.isEmpty ? null : _confirmSelection,
          child: Text("${widget.action} ${counted(_chosen.length, widget.noun)}"),
        ),
      ],
    );
  }
}
