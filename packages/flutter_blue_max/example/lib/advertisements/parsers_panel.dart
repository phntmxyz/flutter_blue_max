import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_editor.dart';
import 'package:flutter_blue_max_example/advertisements/parser_examples.dart';
import 'package:flutter_blue_max_example/advertisements/parser_files.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/shared/noun.dart';
import 'package:flutter_blue_max_example/shared/prompts.dart';
import 'package:flutter_blue_max_example/shared/selection_dialog.dart';

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
              onPressed: () => c.addParsers(testDongleParsers),
              icon: const Icon(Icons.restore),
              label: const Text('Add test dongle parsers'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import'),
            ),
            Builder(
              // The share sheet on iPad anchors to this button.
              builder: (button) => OutlinedButton.icon(
                onPressed: c.parsers.isEmpty ? null : () => _export(button),
                icon: const Icon(Icons.save_alt),
                label: const Text('Export'),
              ),
            ),
            TextButton.icon(
              onPressed: () => _reset(context),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset parsers'),
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
                [parser.summary, for (final field in parser.fields) field.summary(parser.records)].join('\n'),
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

  Future<void> _import(BuildContext context) async {
    final List<AdvertisementParser>? parsers;
    try {
      parsers = await openParserFile();
    } on Exception catch (exception) {
      if (context.mounted) {
        tell(context, 'Import failed: ${exception is FormatException ? exception.message : exception}');
      }
      return;
    }
    if (parsers == null || !context.mounted) {
      return;
    }
    if (parsers.isEmpty) {
      tell(context, 'The file holds no parsers.');
      return;
    }
    final chosen = await _choose(context, title: 'Import parsers', action: 'Import', parsers: parsers);
    if (chosen == null) {
      return;
    }
    final added = await controller.addParsers(chosen);
    final present = chosen.length - added;
    if (context.mounted) {
      tell(
        context,
        [
          'Imported ${counted(added, parserNoun)}',
          if (present > 0) '${present == 1 ? '1 was' : '$present were'} already present',
        ].join(', '),
      );
    }
  }

  Future<void> _export(BuildContext button) async {
    final chosen = await _choose(button, title: 'Export parsers', action: 'Export', parsers: controller.parsers);
    if (chosen == null || !button.mounted) {
      return;
    }
    final box = button.findRenderObject()! as RenderBox;
    try {
      if (await saveParserFile(chosen, origin: box.localToGlobal(Offset.zero) & box.size) && button.mounted) {
        tell(button, 'Exported ${counted(chosen.length, parserNoun)}');
      }
    } on Exception catch (exception) {
      if (button.mounted) {
        tell(button, 'Export failed: $exception');
      }
    }
  }

  Future<void> _reset(BuildContext context) async {
    final confirmed = await confirm(
      context,
      title: 'Reset parsers?',
      message: 'Every parser is replaced with the test dongle parsers. Export your own parsers first to keep them.',
      action: 'Reset',
    );
    if (confirmed) {
      await controller.resetParsers();
    }
  }

  static Future<List<AdvertisementParser>?> _choose(
    BuildContext context, {
    required String title,
    required String action,
    required List<AdvertisementParser> parsers,
  }) => SelectionDialog.show(
    context,
    title: title,
    action: action,
    noun: parserNoun,
    items: parsers,
    label: (parser) => parser.name,
    details: (parser) => parser.summary,
  );
}
