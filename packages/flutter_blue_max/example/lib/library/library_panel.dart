import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/advertisements/parsers_panel.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/catalog_panel.dart';

/// What the app knows about payloads and GATT databases, saved on this device.
class const LibraryPanel({super.key, required final WorkbenchController controller}) extends StatefulWidget {
  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState() extends State<LibraryPanel> {
  bool _catalog = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.data_object_rounded), label: Text('Parsers')),
                ButtonSegment(value: true, icon: Icon(Icons.account_tree_outlined), label: Text('GATT catalog')),
              ],
              selected: {_catalog},
              onSelectionChanged: (value) => setState(() => _catalog = value.single),
            ),
          ),
        ),
        Expanded(
          child: _catalog ? CatalogPanel(controller: widget.controller) : ParsersPanel(controller: widget.controller),
        ),
      ],
    );
  }
}
