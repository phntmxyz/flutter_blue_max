import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/advertisements/parser_editor.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';

/// Manages every saved parser, including those bound to devices that are not nearby.
class const ParsersPanel({super.key, required final WorkbenchController controller}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Advertisement parsers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Parsers read named values from manufacturer or service data and are saved on this device. '
          'Values appear in a device’s advertisement and tracker history.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => ParserEditorPage.open(context, c),
              icon: const Icon(Icons.add),
              label: const Text('Add parser'),
            ),
            OutlinedButton.icon(
              onPressed: () => c.addExampleParsers(commonParsers),
              icon: const Icon(Icons.restore),
              label: const Text('Add common examples'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (c.parsers.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('No parsers yet.')),
        for (final parser in c.parsers)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              title: Text(parser.name),
              subtitle: Text(
                [parser.summary, for (final field in parser.fields) '${field.name}: ${field.type.label}'].join('\n'),
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit parser',
                    onPressed: () => ParserEditorPage.open(context, c, previous: parser),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Remove parser',
                    onPressed: () => c.removeParser(parser),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
