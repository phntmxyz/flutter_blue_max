import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/catalog_editor.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';
import 'package:flutter_blue_max_example/gatt/gatt_characteristic.dart';

/// A discovered service, named and checked against the GATT catalog when it is known.
class const GattService({
  super.key,
  required final BluetoothService service,
  required final WorkbenchController controller,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final known = controller.knownService(service.uuid);
    final own = known != null && controller.catalog.contains(known);
    final (:missing, :different) = known?.compare(service) ?? (missing: const <String>[], different: const <String>[]);
    final uuid = service.uuid.str.toUpperCase();
    final error = TextStyle(color: Theme.of(context).colorScheme.error);
    return ExpansionTile(
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      tilePadding: EdgeInsets.zero,
      title: GattTitle(
        known?.name ?? uuid,
        style: known == null ? const TextStyle(fontFamily: 'monospace', fontSize: 14) : null,
        expected: (known?.test ?? false) ? missing.isEmpty && different.isEmpty : null,
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
            child: TextButton.icon(
              onPressed: () => CatalogEditorPage.open(
                context,
                controller,
                initial: known ?? KnownService.fromDiscovered(service),
                previous: own ? known : null,
              ),
              icon: Icon(own ? Icons.edit_outlined : Icons.bookmark_add_outlined, size: 18),
              label: Text(own ? 'Edit catalog entry' : 'Add to catalog'),
            ),
          ),
        for (final characteristic in service.characteristics)
          GattCharacteristic(key: ObjectKey(characteristic), characteristic: characteristic, controller: controller),
      ],
    );
  }
}
