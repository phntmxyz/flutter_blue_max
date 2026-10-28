import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';

/// Builds a parser against the device's latest advertisement, previewing every change.
/// Pops with the parser, or with nothing when cancelled.
class const ParserEditorPage({
  super.key,

  /// The device a new parser can be bound to; editing keeps the existing binding.
  final DeviceIdentifier? device,
  final AdvertisementData? advertisement,
  final AdvertisementParser? initial,
}) extends StatefulWidget {
  /// Opens the editor and saves the result, replacing [previous] when editing.
  static Future<void> open(
    BuildContext context,
    WorkbenchController controller, {
    AdvertisementParser? previous,
    DeviceIdentifier? device,
    AdvertisementData? advertisement,
  }) async {
    final parser = await Navigator.of(context).push(
      MaterialPageRoute<AdvertisementParser>(
        builder: (_) => ParserEditorPage(device: device, advertisement: advertisement, initial: previous),
      ),
    );
    if (parser != null) {
      await controller.saveParser(parser, previous: previous);
    }
  }

  @override
  State<ParserEditorPage> createState() => _ParserEditorPageState();
}

/// Form state of one field; controllers keep partially typed numbers intact.
class _FieldDraft() {
  final name = TextEditingController();
  final offset = TextEditingController(text: '0');
  final length = TextEditingController(text: '1');
  final scale = TextEditingController(text: '1');
  final unit = TextEditingController();
  AdvertisementFieldType type = AdvertisementFieldType.uint8;

  void dispose() {
    for (final controller in [name, offset, length, scale, unit]) {
      controller.dispose();
    }
  }
}

class _ParserEditorPageState() extends State<ParserEditorPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _key = TextEditingController();
  final _match = TextEditingController();
  final _matchOffset = TextEditingController(text: '0');
  final _fields = <_FieldDraft>[];
  AdvertisementSource _source = AdvertisementSource.manufacturer;
  bool _deviceOnly = false;

  DeviceIdentifier? get _device => widget.initial?.device ?? widget.device;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _name.text = initial.name;
      _source = initial.source;
      _key.text = switch (initial.source) {
        AdvertisementSource.manufacturer => _companyText(initial.companyId!),
        AdvertisementSource.service => initial.serviceUuid!.str,
      };
      _match.text = PayloadCodec.hex(initial.match);
      _matchOffset.text = '${initial.matchOffset}';
      _deviceOnly = initial.device != null;
      for (final field in initial.fields) {
        _fields.add(
          _FieldDraft()
            ..name.text = field.name
            ..offset.text = '${field.offset}'
            ..length.text = '${field.length}'
            ..scale.text = _number(field.scale)
            ..unit.text = field.unit
            ..type = field.type,
        );
      }
      return;
    }
    // Start from the payload the user is looking at.
    final data = widget.advertisement;
    if (data != null && data.manufacturerData.isNotEmpty) {
      _key.text = _companyText(data.manufacturerData.keys.first);
    } else if (data != null && data.serviceData.isNotEmpty) {
      _source = AdvertisementSource.service;
      _key.text = data.serviceData.keys.first.str;
    }
    _fields.add(_FieldDraft());
  }

  @override
  void dispose() {
    for (final controller in [_name, _key, _match, _matchOffset]) {
      controller.dispose();
    }
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  static String _companyText(int id) => '0x${id.toRadixString(16).padLeft(4, '0').toUpperCase()}';

  static String _number(double value) => value == value.roundToDouble() ? '${value.toInt()}' : '$value';

  int? get _companyId => int.tryParse(_key.text.trim().replaceFirst(RegExp('^0[xX]'), ''), radix: 16);

  Guid? get _serviceUuid {
    try {
      return Guid(_key.text.trim());
    } on Object {
      return null;
    }
  }

  /// The sample bytes for the chosen source, if the latest advertisement carries them.
  List<int>? get _sample {
    final data = widget.advertisement;
    return switch (_source) {
      AdvertisementSource.manufacturer => data?.manufacturerData[_companyId],
      AdvertisementSource.service => data?.serviceData[_serviceUuid],
    };
  }

  /// Null while any input is invalid; the form validators explain why.
  AdvertisementParser? _build() {
    try {
      final companyId = _source == AdvertisementSource.manufacturer ? _companyId : null;
      final serviceUuid = _source == AdvertisementSource.service ? _serviceUuid : null;
      if (companyId == null && serviceUuid == null) {
        return null;
      }
      final fields = [
        for (final draft in _fields)
          AdvertisementField(
            draft.name.text.trim().isEmpty ? 'Field' : draft.name.text.trim(),
            int.parse(draft.offset.text.trim()),
            draft.type,
            length: int.parse(draft.length.text.trim()),
            scale: double.parse(draft.scale.text.trim()),
            unit: draft.unit.text.trim(),
          ),
      ];
      return AdvertisementParser(
        name: _name.text.trim().isEmpty ? 'Parser' : _name.text.trim(),
        source: _source,
        companyId: companyId,
        serviceUuid: serviceUuid,
        match: PayloadCodec.decode(_match.text, hex: true),
        matchOffset: int.parse(_matchOffset.text.trim()),
        device: _deviceOnly ? _device : null,
        fields: fields,
      );
    } on FormatException {
      return null;
    }
  }

  String? _offsetError(String? value) {
    final offset = int.tryParse(value?.trim() ?? '');
    return offset == null || offset < 0 ? 'Enter 0 or more.' : null;
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    final parser = _build();
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Add parser' : 'Edit parser'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () {
                if (_form.currentState!.validate() && parser != null) {
                  Navigator.pop(context, parser);
                }
              },
              child: const Text('Save parser'),
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
              decoration: const InputDecoration(labelText: 'Parser name', hintText: 'Flower care'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a name.' : null,
            ),
            const SizedBox(height: 16),
            SegmentedButton<AdvertisementSource>(
              segments: [
                for (final source in AdvertisementSource.values)
                  ButtonSegment(value: source, label: Text(source.label)),
              ],
              selected: {_source},
              onSelectionChanged: (value) => setState(() {
                _source = value.single;
                _key.clear();
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _key,
              decoration: InputDecoration(
                labelText: _source == AdvertisementSource.manufacturer ? 'Company ID (hex)' : 'Service UUID',
                hintText: _source == AdvertisementSource.manufacturer ? '0x0499' : 'fe95',
              ),
              validator: (_) {
                if (_source == AdvertisementSource.manufacturer) {
                  final id = _companyId;
                  return id == null || id > 0xffff ? 'Enter a 16-bit hex company ID.' : null;
                }
                return _serviceUuid == null ? 'Enter a 16, 32 or 128-bit UUID.' : null;
              },
            ),
            const SizedBox(height: 16),
            Text('Sample from this device', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (sample == null)
              Text(
                'The latest advertisement has no payload for this source. '
                'Offsets count from the first byte after the company ID.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final (offset, byte) in sample.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        children: [
                          Text('$offset', style: Theme.of(context).textTheme.labelSmall),
                          Text(PayloadCodec.hex([byte]), style: mono),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 20),
            Text('Match', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Optional bytes the payload must contain, e.g. a frame type. Leave empty to parse every payload.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    controller: _matchOffset,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'At offset'),
                    validator: _offsetError,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _match,
                    decoration: const InputDecoration(labelText: 'Bytes (hex)', hintText: '05'),
                    validator: (value) {
                      try {
                        PayloadCodec.decode(value ?? '', hex: true);
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_device != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Only this device'),
                subtitle: Text('${_device!.str}. Otherwise every device with a matching payload is parsed.'),
                value: _deviceOnly,
                onChanged: (value) => setState(() => _deviceOnly = value),
              ),
            const SizedBox(height: 12),
            Text('Fields', style: Theme.of(context).textTheme.titleSmall),
            for (final draft in _fields) ...[const SizedBox(height: 12), _fieldCard(draft)],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _fields.add(_FieldDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add field'),
            ),
            if (sample != null) ...[
              const SizedBox(height: 20),
              Text('Preview', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SelectableText(() {
                if (parser == null) {
                  return 'Complete the form to preview.';
                }
                final lines = parser.read(companyId: parser.companyId, serviceUuid: parser.serviceUuid, bytes: sample);
                return lines.isEmpty ? 'The sample does not match.' : lines.join('\n');
              }(), style: mono),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldCard(_FieldDraft draft) {
    final variable = draft.type.size == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: draft.name,
                    decoration: const InputDecoration(labelText: 'Field name', hintText: 'Temperature'),
                    validator: (value) => (value ?? '').trim().isEmpty ? 'Enter a name.' : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove field',
                  onPressed: _fields.length > 1
                      ? () => setState(() {
                          _fields.remove(draft);
                          draft.dispose();
                        })
                      : null,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 96,
                  child: TextFormField(
                    controller: draft.offset,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Offset'),
                    validator: _offsetError,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<AdvertisementFieldType>(
                    initialValue: draft.type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final type in AdvertisementFieldType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) => setState(() => draft.type = value!),
                  ),
                ),
                if (variable)
                  SizedBox(
                    width: 96,
                    child: TextFormField(
                      controller: draft.length,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Bytes'),
                      validator: (value) {
                        final length = int.tryParse(value?.trim() ?? '');
                        return length == null || length < 1 ? 'Enter 1 or more.' : null;
                      },
                    ),
                  )
                else ...[
                  SizedBox(
                    width: 96,
                    child: TextFormField(
                      controller: draft.scale,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Scale'),
                      validator: (value) => double.tryParse(value?.trim() ?? '') == null ? 'Enter a number.' : null,
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: TextFormField(
                      controller: draft.unit,
                      decoration: const InputDecoration(labelText: 'Unit', hintText: '°C'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
