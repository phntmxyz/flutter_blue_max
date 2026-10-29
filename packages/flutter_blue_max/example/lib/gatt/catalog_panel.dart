import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/catalog_editor.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';

/// Lists the user's own GATT catalog services and the built-in ones they can extend or replace.
class const CatalogPanel({super.key, required final WorkbenchController controller}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = controller;
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
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => CatalogEditorPage.open(context, c),
            icon: const Icon(Icons.add),
            label: const Text('Add service'),
          ),
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
          _ServiceCard(
            service: service,
            note: switch (builtInService(service.uuid)) {
              final replaced? => 'Replaces the built-in ${replaced.name}',
              null => null,
            },
            actions: [
              TextButton.icon(
                onPressed: () => CatalogEditorPage.open(context, c, previous: service),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: () => c.removeCatalogService(service),
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
            _ServiceCard(
              service: service,
              note: c.catalog.any((own) => own.uuid == service.uuid) ? 'Replaced by your entry' : null,
              actions: [
                TextButton.icon(
                  onPressed: () => CatalogEditorPage.open(context, c, initial: service),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy to your services'),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class const _ServiceCard({required final KnownService service, required final List<Widget> actions, final String? note})
    extends StatelessWidget {
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
                '${service.characteristics.length} ${service.characteristics.length == 1 ? 'characteristic' : 'characteristics'}',
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
                  if (characteristic.properties case final properties?)
                    Text(
                      GattProperty.values.where(properties.contains).map((property) => property.label).join(' · '),
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
