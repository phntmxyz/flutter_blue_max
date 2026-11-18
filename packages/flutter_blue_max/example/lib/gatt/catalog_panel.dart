import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/gatt/catalog_editor_page.dart';
import 'package:flutter_blue_max_example/gatt/catalog_files.dart';
import 'package:flutter_blue_max_example/gatt/catalog_import_result.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog_library.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/noun.dart';
import 'package:flutter_blue_max_example/shared/persisted_library.dart';
import 'package:flutter_blue_max_example/shared/prompts.dart';
import 'package:flutter_blue_max_example/shared/selection_dialog.dart';
import 'package:provider/provider.dart';

const _characteristicNoun = ('characteristic', 'characteristics');

/// GATT catalog section of `LibraryPanel`.
/// Lists the user's own GATT catalog services and the built-in ones they can extend or replace.
class const CatalogPanel({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    context.select<GattCatalogLibrary, Object?>((c) => c.catalog);
    final c = context.read<GattCatalogLibrary>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('GATT catalog', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Names services and characteristics in the GATT explorer. Checked services must contain every '
          'characteristic with exactly its properties. Your entries are saved on this device and replace '
          'built-in ones with the same UUID.',
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => CatalogEditorPage.open(context),
              icon: const Icon(Icons.add),
              label: const Text('Add service'),
            ),
            OutlinedButton.icon(
              onPressed: () => _import(context),
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('Import'),
            ),
            Builder(
              // The share sheet on iPad anchors to this button.
              builder: (button) {
                return OutlinedButton.icon(
                  onPressed: c.catalog.isEmpty ? null : () => _export(button),
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Export'),
                );
              },
            ),
            TextButton.icon(
              onPressed: () => _reset(context),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset catalog'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Your services', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (c.catalog.isEmpty)
          Text(
            'None yet. Add a service here or from a discovered service in the GATT explorer.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        for (final service in c.catalog)
          CatalogServiceCard(
            service: service,
            note: switch (builtInService(service.uuid)) {
              final replaced? => 'Replaces the built-in ${replaced.name}',
              null => null,
            },
            actions: [
              TextButton.icon(
                onPressed: () => CatalogEditorPage.open(context, previous: service),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => c.remove(service),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove'),
              ),
            ],
          ),
        for (final (title, services) in [
          ('FBM test dongle', testDongleServices),
          ('Bluetooth SIG and common vendors', standardServices),
        ]) ...[
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final service in services)
            CatalogServiceCard(
              service: service,
              note: c.catalog.any((own) => own.uuid == service.uuid) ? 'Replaced by your entry' : null,
              actions: [
                TextButton.icon(
                  onPressed: () => CatalogEditorPage.open(context, initial: service),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy to your services'),
                ),
              ],
            ),
        ],
      ],
    );
  }

  Future<void> _import(BuildContext context) async {
    final controller = context.read<GattCatalogLibrary>();
    final List<KnownService>? services;
    try {
      services = await openCatalogFile();
    } on Exception catch (exception, stackTrace) {
      if (exception is! FormatException) {
        developer.log('Import catalog services failed', name: 'workbench', error: exception, stackTrace: stackTrace);
      }
      if (context.mounted) {
        tell(
          context,
          'Import failed: ${exception is FormatException ? exception.toString().replaceFirst('FormatException: ', '') : exception}',
        );
      }
      return;
    }
    if (services == null || !context.mounted) {
      return;
    }
    if (services.isEmpty) {
      tell(context, 'The file holds no services.');
      return;
    }
    final replacements = await controller.previewReplacements(services);
    if (!context.mounted) {
      return;
    }
    final chosen = await _choose(context, services: services, replacements: replacements);
    if (chosen == null) {
      return;
    }
    final LibraryChange<CatalogImportResult> change;
    try {
      change = await controller.addCatalogServices(chosen, confirmedReplacements: replacements);
    } on CatalogConflict catch (exception) {
      if (context.mounted) {
        tell(context, exception.message);
      }
      return;
    }
    if (!change.saved) {
      return;
    }
    final result = change.value;
    final added = result.added;
    final replaced = result.replaced;
    final present = result.present;
    if (context.mounted) {
      tell(
        context,
        [
          'Imported ${counted(added + replaced, serviceNoun)}',
          if (replaced > 0) '$replaced replaced your own',
          if (present > 0) '${present == 1 ? '1 was' : '$present were'} already present',
        ].join(', '),
      );
    }
  }

  Future<void> _export(BuildContext button) async {
    final chosen = await _choose(button, services: button.read<GattCatalogLibrary>().catalog);
    if (chosen == null || !button.mounted) {
      return;
    }
    final box = button.findRenderObject()! as RenderBox;
    try {
      final saved = await saveCatalogFile(chosen, origin: box.localToGlobal(Offset.zero) & box.size);
      if (!saved) {
        return;
      }
      if (button.mounted) {
        tell(button, 'Exported ${counted(chosen.length, serviceNoun)}');
      }
    } on Exception catch (exception, stackTrace) {
      developer.log('Export catalog services failed', name: 'workbench', error: exception, stackTrace: stackTrace);
      if (button.mounted) {
        tell(button, 'Export failed: $exception');
      }
    }
  }

  Future<void> _reset(BuildContext context) async {
    final controller = context.read<GattCatalogLibrary>();
    final confirmed = await confirm(
      context,
      title: 'Reset catalog?',
      message: 'Your own services are removed; the built-in entries stay. Export your services first to keep them.',
      action: 'Reset',
    );
    if (confirmed) {
      await controller.reset();
    }
  }

  /// An import marks services that would replace a different own entry, so none is overwritten unnoticed.
  Future<List<KnownService>?> _choose(
    BuildContext context, {
    required List<KnownService> services,
    Map<Guid, KnownService>? replacements,
  }) {
    Widget summary(KnownService service) =>
        Text('${service.uuid.str.toUpperCase()} · ${counted(service.characteristics.length, _characteristicNoun)}');

    if (replacements != null) {
      return SelectionDialog.show(
        context,
        title: const Text('Import services'),
        action: 'Import',
        noun: serviceNoun,
        items: services,
        label: (s) => Text(s.name),
        details: (service) =>
            CatalogImportDetails(summary: summary(service), previousName: replacements[service.uuid]?.name),
      );
    }
    return SelectionDialog.show(
      context,
      title: const Text('Export services'),
      action: 'Export',
      noun: serviceNoun,
      items: services,
      label: (s) => Text(s.name),
      details: summary,
    );
  }
}

/// Service summary and confirmed replacement warning for a catalog import row.
class const CatalogImportDetails({required final Widget summary, final String? previousName}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final previous = previousName;
    final color = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        summary,
        if (previous != null)
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Replaces your $previous', style: TextStyle(color: color)),
              ),
            ],
          ),
      ],
    );
  }
}

/// A catalog service and its actions in the Library catalog section.
class const CatalogServiceCard({
  required final KnownService service,
  required final List<Widget> actions,
  final String? note,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 11);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(service.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.uuid.str.toUpperCase(), style: mono),
            Text(
              [
                counted(service.characteristics.length, _characteristicNoun),
                if (service.test) 'Checked' else 'Names only',
                ?note,
              ].join(' · '),
            ),
          ],
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          for (final characteristic in service.characteristics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(characteristic.name),
                  Text(characteristic.uuid.str.toUpperCase(), style: mono),
                  if (characteristic.properties != null)
                    Text(
                      GattProperty.values.where(characteristic.properties!.contains).map((p) => p.label).join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          Wrap(spacing: 8, children: actions),
        ],
      ),
    );
  }
}
