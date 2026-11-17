import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/catalog_editor_page.dart';
import 'package:flutter_blue_max_example/gatt/gatt_characteristic.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:provider/provider.dart';

/// One service in the GATT explorer of `DevicesPanel`.
/// A discovered service, named and checked against the GATT catalog when it is known.
class const GattService({super.key, required final BluetoothService service}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final known = context.read<WorkbenchController>().knownService(service.uuid);
    final own = known != null && context.read<WorkbenchController>().catalog.contains(known);
    final (:missing, :different) = known?.compare(service) ?? (missing: const <String>[], different: const <String>[]);
    final isTestEntry = known?.test ?? false;
    final matches = missing.isEmpty && different.isEmpty;
    final expected = isTestEntry ? matches : null;
    final uuid = service.uuid.str.toUpperCase();
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return ExpansionTile(
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      tilePadding: EdgeInsets.zero,
      title: GattTitle(
        title: Text(
          known?.name ?? uuid,
          style: known == null ? const TextStyle(fontFamily: 'monospace', fontSize: 14) : null,
        ),
        expected: expected,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (known != null) Text(uuid, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          Text(
            '${service.characteristics.length} ${service.characteristics.length == 1 ? 'characteristic' : 'characteristics'} · '
            '${service.isPrimary ? 'Primary' : 'Secondary'} service',
          ),
          if (missing.isNotEmpty) Text('Missing: ${missing.join(', ')}', style: error),
          if (different.isNotEmpty) Text('Unexpected properties: ${different.join(', ')}', style: error),
        ],
      ),
      children: [
        // Built-in entries are edited by adding an own entry from the catalog, not from a device.
        if (known == null || own)
          Align(
            alignment: Alignment.centerLeft,
            child: Builder(
              builder: (context) {
                if (own) {
                  return TextButton.icon(
                    onPressed: () => CatalogEditorPage.open(context, previous: known),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit catalog entry'),
                  );
                }
                return TextButton.icon(
                  onPressed: () => CatalogEditorPage.open(context, initial: KnownService.fromDiscovered(service)),
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: const Text('Add to catalog'),
                );
              },
            ),
          ),
        for (final characteristic in service.characteristics)
          GattCharacteristic(key: ObjectKey(characteristic), characteristic: characteristic),
      ],
    );
  }
}
