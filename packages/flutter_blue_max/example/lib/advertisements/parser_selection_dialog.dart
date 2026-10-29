import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';

/// Lets the user choose all or some [parsers], all selected at first.
/// Pops with the chosen parsers, or with nothing when cancelled.
class const ParserSelectionDialog({
  super.key,
  required final String title,

  /// The confirm button, e.g. "Export", followed by the number of chosen parsers.
  required final String action,
  required final List<AdvertisementParser> parsers,
}) extends StatefulWidget {
  static Future<List<AdvertisementParser>?> show(
    BuildContext context, {
    required String title,
    required String action,
    required List<AdvertisementParser> parsers,
  }) => showDialog<List<AdvertisementParser>>(
    context: context,
    builder: (_) => ParserSelectionDialog(title: title, action: action, parsers: parsers),
  );

  @override
  State<ParserSelectionDialog> createState() => _ParserSelectionDialogState();
}

class _ParserSelectionDialogState() extends State<ParserSelectionDialog> {
  /// Indices, since equal parsers can appear twice in a file.
  late final _chosen = {for (var i = 0; i < widget.parsers.length; i++) i};

  @override
  Widget build(BuildContext context) {
    final parsers = widget.parsers;
    final all = _chosen.length == parsers.length;
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: SizedBox(
        width: 480,
        child: ListView(
          shrinkWrap: true,
          children: [
            CheckboxListTile(
              tristate: true,
              value: all ? true : (_chosen.isEmpty ? false : null),
              title: const Text('All parsers'),
              onChanged: (_) => setState(() {
                if (all) {
                  _chosen.clear();
                } else {
                  _chosen.addAll([for (var i = 0; i < parsers.length; i++) i]);
                }
              }),
            ),
            const Divider(),
            for (final (index, parser) in parsers.indexed)
              CheckboxListTile(
                value: _chosen.contains(index),
                title: Text(parser.name),
                subtitle: Text(parser.summary),
                onChanged: (value) => setState(() => value! ? _chosen.add(index) : _chosen.remove(index)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.pop(context, [
                  for (final (index, parser) in parsers.indexed)
                    if (_chosen.contains(index)) parser,
                ]),
          child: Text('${widget.action} ${_chosen.length} ${_chosen.length == 1 ? 'parser' : 'parsers'}'),
        ),
      ],
    );
  }
}
