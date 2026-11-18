import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/gatt/gatt_catalog_library.dart';
import 'package:flutter_blue_max_example/gatt/known_service.dart';
import 'package:flutter_blue_max_example/shared/form_validation.dart';
import 'package:flutter_blue_max_example/shared/prompts.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Opened from `CatalogPanel` to add/edit/copy, and from `GattService` to add or edit an entry.
/// Saves one of the user's own GATT catalog services and keeps the editor open on conflicts.
class const CatalogEditorPage({
  super.key,
  final KnownService? initial,
  required final Future<void> Function(KnownService) onSave,

  /// The user's other services, whose UUIDs this one must not reuse.
  final List<KnownService> others = const [],
  final bool editing = false,
}) extends StatefulWidget {
  /// Opens the editor and saves the result, replacing [previous] when editing.
  /// [initial] prefills a new entry, e.g. from a discovered service.
  static Future<void> open(BuildContext context, {KnownService? initial, KnownService? previous}) async {
    final controller = context.read<GattCatalogLibrary>();
    await controller.load();
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return CatalogEditorPage(
            initial: initial ?? previous,
            onSave: (service) => controller.save(service, previous: previous),
            editing: previous != null,
            others: [
              for (final service in controller.catalog)
                if (service != previous) service,
            ],
          );
        },
      ),
    );
  }

  @override
  State<CatalogEditorPage> createState() => _CatalogEditorPageState();
}

class _CatalogEditorPageState() extends State<CatalogEditorPage> {
  bool _saving = false;
  final _name = FormControl<String>(value: '');
  final _uuid = FormControl<String>(value: '');
  final _characteristicForms = FormArray<Map<String, dynamic>>([]);
  final _check = FormControl<bool>(value: true);
  late final _form = FormGroup(
    {'name': _name, 'uuid': _uuid, 'check': _check, 'characteristics': _characteristicForms},
    validators: [DelegateValidator(_validate)],
  );
  StreamSubscription<Object?>? _changes;
  List<CharacteristicDraft> get _characteristics => _characteristicForms.controls.cast<CharacteristicDraft>();
  bool get _test => _check.value!;
  set _test(bool value) => _check.value = value;

  Map<String, dynamic>? _validate(AbstractControl<dynamic> control) {
    final form = control as FormGroup;
    setInputError(form.control('name'), _required(_name.text));
    final uuid = _parse(_uuid.text);
    String? message;
    if (uuid == null) {
      message = 'Enter a 16, 32 or 128-bit UUID.';
    } else if (widget.others.any((service) => service.uuid == uuid)) {
      message = 'Your catalog already has this service.';
    }
    setInputError(form.control('uuid'), message);
    for (final draft in _characteristics) {
      setInputError(draft.name, _required(draft.name.text));
      final uuid = draft.parsedUuid;
      String? message;
      if (uuid == null) {
        message = 'Enter a 16, 32 or 128-bit UUID.';
      } else if (_characteristics.where((other) => other.parsedUuid == uuid).length > 1) {
        message = 'This service already has this characteristic.';
      }
      setInputError(draft.uuid, message);
      setInputError(
        draft.propertyControl,
        _test && draft.properties.isEmpty ? 'Select the expected properties.' : null,
      );
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _changes = _form.valueChanges.listen((_) => setState(() {}));
    final initial = widget.initial;
    if (initial == null) {
      _characteristicForms.add(CharacteristicDraft());
      return;
    }
    _name.text = initial.name;
    _uuid.text = initial.uuid.str;
    _test = initial.test;
    for (final characteristic in initial.characteristics) {
      _characteristicForms.add(
        CharacteristicDraft()
          ..name.text = characteristic.name
          ..uuid.text = characteristic.uuid.str
          ..properties = Set.of(characteristic.properties ?? {}),
      );
    }
  }

  @override
  void dispose() {
    _changes?.cancel();
    _form.dispose();
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

  Future<void> _save() async {
    if (!_form.valid) {
      _form.markAllAsTouched();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(_build());
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } on CatalogConflict catch (exception) {
      if (mounted) {
        tell(context, exception.message);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _removeCharacteristic(CharacteristicDraft draft) {
    setState(() => _characteristicForms.removeAt(_characteristics.indexOf(draft)));
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
  }

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
            child: FilledButton(onPressed: _saving ? null : _save, child: const Text('Save entry')),
          ),
        ],
      ),
      body: ReactiveForm(
        formGroup: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ReactiveTextField<String>(
              key: ObjectKey(_name),
              formControl: _name,
              decoration: const InputDecoration(labelText: 'Service name', hintText: 'My sensor'),
              validationMessages: inputValidationMessages,
            ),
            const SizedBox(height: 16),
            ReactiveTextField<String>(
              key: ObjectKey(_uuid),
              formControl: _uuid,
              decoration: InputDecoration(
                labelText: 'Service UUID',
                hintText: '180f',
                helperText: replaced == null ? null : 'Replaces the built-in entry ${replaced.name}.',
              ),
              validationMessages: inputValidationMessages,
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
            for (final draft in _characteristics) ...[
              const SizedBox(height: 12),
              CatalogCharacteristicCard(
                key: ObjectKey(draft),
                draft: draft,
                checkProperties: _test,
                onRemove: () => _removeCharacteristic(draft),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _characteristicForms.add(CharacteristicDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add characteristic'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form state of one characteristic.
class CharacteristicDraft() extends FormGroup {
  this
    : super({
        'name': FormControl<String>(value: ''),
        'uuid': FormControl<String>(value: ''),
        'properties': FormControl<Set<GattProperty>>(value: {}),
      });
  FormControl<String> get name => control('name') as FormControl<String>;
  FormControl<String> get uuid => control('uuid') as FormControl<String>;
  FormControl<Set<GattProperty>> get propertyControl => control('properties') as FormControl<Set<GattProperty>>;
  Set<GattProperty> get properties => propertyControl.value!;
  set properties(Set<GattProperty> value) => propertyControl.value = value;
  Guid? get parsedUuid => _parse(uuid.text);
}

Guid? _parse(String text) {
  try {
    return text.trim().isEmpty ? null : Guid(text.trim());
  } on Object {
    return null;
  }
}

/// One keyed characteristic form within CatalogEditorPage; the page owns its draft lifecycle.
class const CatalogCharacteristicCard({
  super.key,
  required final CharacteristicDraft draft,
  required final bool checkProperties,
  required final VoidCallback onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ReactiveTextField<String>(
                    key: ObjectKey(draft.name),
                    formControl: draft.name,
                    decoration: const InputDecoration(labelText: 'Characteristic name', hintText: 'Temperature'),
                    validationMessages: inputValidationMessages,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove characteristic',
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReactiveTextField<String>(
              key: ObjectKey(draft.uuid),
              formControl: draft.uuid,
              decoration: const InputDecoration(labelText: 'Characteristic UUID', hintText: '2a6e'),
              validationMessages: inputValidationMessages,
            ),
            if (checkProperties) ...[
              const SizedBox(height: 12),
              ReactiveFormField<Set<GattProperty>, Set<GattProperty>>(
                formControl: draft.propertyControl,
                builder: (field) {
                  return Column(
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
                              onSelected: (it) {
                                if (it) {
                                  draft.properties = {...draft.properties, property};
                                } else {
                                  draft.properties = {...draft.properties}..remove(property);
                                }
                              },
                            ),
                        ],
                      ),
                      if (field.control.touched && field.control.hasError('input')) ...[
                        const SizedBox(height: 6),
                        Text(
                          field.control.getError('input')! as String,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Enter a name.' : null;
