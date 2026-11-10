import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog.dart';

/// Edits one of the user's own GATT catalog services. Pops with the service, or with nothing when cancelled.
class const CatalogEditorPage({
  super.key,
  final KnownService? initial,

  /// The user's other services, whose UUIDs this one must not reuse.
  final List<KnownService> others = const [],
  final bool editing = false,
}) extends StatefulWidget {
  /// Opens the editor and saves the result, replacing [previous] when editing.
  /// [initial] prefills a new entry, e.g. from a discovered service.
  static Future<void> open(
    BuildContext context,
    WorkbenchController controller, {
    KnownService? initial,
    KnownService? previous,
  }) async {
    final service = await Navigator.of(context).push(
      MaterialPageRoute<KnownService>(
        builder: (_) => CatalogEditorPage(
          initial: initial ?? previous,
          editing: previous != null,
          others: [
            for (final service in controller.catalog)
              if (service != previous) service,
          ],
        ),
      ),
    );
    if (service != null) {
      await controller.saveCatalogService(service, previous: previous);
    }
  }

  @override
  State<CatalogEditorPage> createState() => _CatalogEditorPageState();
}

/// Form state of one characteristic.
class _CharacteristicDraft() {
  final name = TextEditingController();
  final uuid = TextEditingController();
  final properties = <GattProperty>{};

  Guid? get parsedUuid => _parse(uuid.text);

  void dispose() {
    name.dispose();
    uuid.dispose();
  }
}

Guid? _parse(String text) {
  try {
    return text.trim().isEmpty ? null : Guid(text.trim());
  } on Object {
    return null;
  }
}

class _CatalogEditorPageState() extends State<CatalogEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _uuid = TextEditingController();
  final _characteristics = <_CharacteristicDraft>[];
  bool _test = true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) {
      _characteristics.add(_CharacteristicDraft());
      return;
    }
    _name.text = initial.name;
    _uuid.text = initial.uuid.str;
    _test = initial.test;
    for (final characteristic in initial.characteristics) {
      _characteristics.add(
        _CharacteristicDraft()
          ..name.text = characteristic.name
          ..uuid.text = characteristic.uuid.str
          ..properties.addAll(characteristic.properties ?? {}),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _uuid.dispose();
    for (final characteristic in _characteristics) {
      characteristic.dispose();
    }
    super.dispose();
  }

  KnownService _build() => KnownService(_parse(_uuid.text)!, _name.text.trim(), test: _test, [
    for (final draft in _characteristics)
      KnownCharacteristic(
        draft.parsedUuid!,
        draft.name.text.trim(),
        properties: _test ? Set.of(draft.properties) : null,
      ),
  ]);

  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Enter a name.' : null;

  @override
  Widget build(BuildContext context) {
    final replaced = switch (_parse(_uuid.text)) {
      final uuid? => builtInService(uuid),
      null => null,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Edit catalog entry' : 'Add catalog entry'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _build());
                }
              },
              child: const Text('Save entry'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Service name', hintText: 'My sensor'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _uuid,
              decoration: InputDecoration(
                labelText: 'Service UUID',
                hintText: '180f',
                helperText: replaced == null ? null : 'Replaces the built-in entry ${replaced.name}.',
              ),
              validator: (value) {
                final uuid = _parse(value ?? '');
                if (uuid == null) {
                  return 'Enter a 16, 32 or 128-bit UUID.';
                }
                if (widget.others.any((service) => service.uuid == uuid)) {
                  return 'Your catalog already has this service.';
                }
                return null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Check characteristics'),
              subtitle: const Text(
                'Discovered services must contain every characteristic with exactly the selected properties. '
                'Otherwise the entry only names them.',
              ),
              value: _test,
              onChanged: (value) => setState(() => _test = value),
            ),
            const SizedBox(height: 12),
            Text('Characteristics', style: Theme.of(context).textTheme.titleSmall),
            for (final draft in _characteristics) ...[const SizedBox(height: 12), _characteristicCard(draft)],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _characteristics.add(_CharacteristicDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add characteristic'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _characteristicCard(_CharacteristicDraft draft) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.name,
                    decoration: const InputDecoration(labelText: 'Characteristic name', hintText: 'Temperature'),
                    validator: _required,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove characteristic',
                  onPressed: () => setState(() {
                    _characteristics.remove(draft);
                    draft.dispose();
                  }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.uuid,
              decoration: const InputDecoration(labelText: 'Characteristic UUID', hintText: '2a6e'),
              validator: (value) {
                final uuid = _parse(value ?? '');
                if (uuid == null) {
                  return 'Enter a 16, 32 or 128-bit UUID.';
                }
                if (_characteristics.where((other) => other.parsedUuid == uuid).length > 1) {
                  return 'This service already has this characteristic.';
                }
                return null;
              },
            ),
            if (_test) ...[
              const SizedBox(height: 12),
              FormField<void>(
                validator: (_) => draft.properties.isEmpty ? 'Select the expected properties.' : null,
                builder: (field) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final property in GattProperty.values)
                          FilterChip(
                            label: Text(property.label),
                            selected: draft.properties.contains(property),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  draft.properties.add(property);
                                } else {
                                  draft.properties.remove(property);
                                }
                              });
                              field.didChange(null);
                            },
                          ),
                      ],
                    ),
                    if (field.errorText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        field.errorText!,
                        style: Theme.of(context).textTheme.bodySmall!
                            .copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
