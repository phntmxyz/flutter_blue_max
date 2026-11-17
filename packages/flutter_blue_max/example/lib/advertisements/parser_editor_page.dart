import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/advertisements/parser_library.dart';
import 'package:flutter_blue_max_example/shared/form_validation.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:provider/provider.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Opened from `AdvertisementCard` or `ParsersPanel`.
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
    BuildContext context, {
    AdvertisementParser? previous,
    DeviceIdentifier? device,
    AdvertisementData? advertisement,
  }) async {
    final controller = context.read<ParserLibrary>();
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

class _ParserEditorPageState() extends State<ParserEditorPage> {
  final _name = FormControl<String>(value: '');
  final _key = FormControl<String>(value: '');
  final _match = FormControl<String>(value: '');
  final _matchOffset = FormControl<String>(value: '0');
  final _recordOffset = FormControl<String>(value: '0');
  final _fieldForms = FormArray<Map<String, dynamic>>([]);
  List<ParserFieldDraft> get _fields => _fieldForms.controls.cast<ParserFieldDraft>();
  final _sourceControl = FormControl<AdvertisementSource>(value: AdvertisementSource.manufacturer);
  AdvertisementSource get _source => _sourceControl.value!;
  set _source(AdvertisementSource value) => _sourceControl.value = value;
  final _recordsControl = FormControl<bool>(value: false);
  bool get _records => _recordsControl.value!;
  set _records(bool value) => _recordsControl.value = value;
  final _recordTypeControl = FormControl<RecordTypeFormat>(value: RecordTypeFormat.uint8);
  RecordTypeFormat get _recordType => _recordTypeControl.value!;
  set _recordType(RecordTypeFormat value) => _recordTypeControl.value = value;
  final _recordLengthControl = FormControl<RecordLength>(value: RecordLength.afterType);
  RecordLength get _recordLength => _recordLengthControl.value!;
  set _recordLength(RecordLength value) => _recordLengthControl.value = value;
  final _deviceOnlyControl = FormControl<bool>(value: false);
  bool get _deviceOnly => _deviceOnlyControl.value!;
  set _deviceOnly(bool value) => _deviceOnlyControl.value = value;
  late final _form = FormGroup(
    {
      'name': _name,
      'key': _key,
      'match': _match,
      'matchOffset': _matchOffset,
      'recordOffset': _recordOffset,
      'source': _sourceControl,
      'records': _recordsControl,
      'recordType': _recordTypeControl,
      'recordLength': _recordLengthControl,
      'deviceOnly': _deviceOnlyControl,
      'fields': _fieldForms,
    },
    validators: [DelegateValidator(_validate)],
  );
  StreamSubscription<Object?>? _changes;

  DeviceIdentifier? get _device => widget.initial?.device ?? widget.device;

  @override
  void initState() {
    super.initState();
    _changes = _form.valueChanges.listen((_) => setState(() {}));
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
      final records = initial.records;
      if (records != null) {
        _records = true;
        _recordOffset.text = '${records.offset}';
        _recordType = records.type;
        _recordLength = records.length;
      }
      _deviceOnly = initial.device != null;
      for (final field in initial.fields) {
        _fieldForms.add(
          ParserFieldDraft()
            ..name.text = field.name
            ..offset.text = '${field.offset}'
            ..length.text = '${field.length}'
            ..scale.text = _number(field.scale)
            ..add.text = _number(field.add)
            ..unit.text = field.unit
            ..record.text = field.record == null ? '' : field.record!.toRadixString(16).toUpperCase()
            ..bit.text = '${field.bit}'
            ..bits.text = field.bits == null ? '' : '${field.bits}'
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
    _fieldForms.add(ParserFieldDraft());
  }

  @override
  void dispose() {
    _changes?.cancel();
    _form.dispose();
    super.dispose();
  }

  int? get _companyId => _hexNumber(_key.text);

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

  Map<String, dynamic>? _validate(AbstractControl<dynamic> control) {
    setInputError(_name, _required(_name.text));
    String? keyError;
    if (_source == AdvertisementSource.manufacturer) {
      final id = _companyId;
      if (id == null || id < 0 || id > 0xffff) keyError = 'Enter a 16-bit hex company ID.';
    } else if (_serviceUuid == null) {
      keyError = 'Enter a 16, 32 or 128-bit UUID.';
    }
    setInputError(_key, keyError);
    setInputError(_matchOffset, _offsetError(_matchOffset.text));
    String? matchError;
    try {
      PayloadCodec.decode(_match.text, hex: true);
    } on FormatException catch (error) {
      matchError = error.message;
    }
    setInputError(_match, matchError);
    setInputError(_recordOffset, _records ? _offsetError(_recordOffset.text) : null);
    for (final draft in _fields) {
      setInputError(draft.name, _required(draft.name.text));
      setInputError(draft.offset, _offsetError(draft.offset.text));
      final record = _hexNumber(draft.record.text);
      final recordBits = _recordType.size * 8;
      String? recordError;
      if (_records && (record == null || record < 0 || record >= 1 << recordBits)) {
        recordError = 'Enter a $recordBits-bit hex type.';
      }
      setInputError(draft.record, recordError);
      final variable = draft.type.size == null;
      final length = int.tryParse(draft.length.text.trim());
      setInputError(draft.length, variable && (length == null || length < 1) ? 'Enter 1 or more.' : null);
      final scale = double.tryParse(draft.scale.text.trim());
      setInputError(
        draft.scale,
        !variable && (scale == null || !scale.isFinite || scale == 0) ? 'Enter a non-zero number.' : null,
      );
      final add = double.tryParse(draft.add.text.trim());
      setInputError(draft.add, !variable && (add == null || !add.isFinite) ? 'Enter a number.' : null);
      setInputError(draft.bit, draft.type.unsigned ? _offsetError(draft.bit.text) : null);
      String? bitsError;
      if (draft.type.unsigned && draft.bits.text.trim().isNotEmpty) {
        final available = draft.type.size! * 8 - (int.tryParse(draft.bit.text.trim()) ?? 0);
        final bits = int.tryParse(draft.bits.text.trim());
        if (bits == null || bits < 1 || bits > available) bitsError = 'Enter 1 to $available.';
      }
      setInputError(draft.bits, bitsError);
    }
    return null;
  }

  /// Preview and Save use the same model validation, including hidden-field rules.
  AdvertisementParser? _build() {
    if (!_form.valid) return null;
    final fields = <AdvertisementField>[];
    for (final draft in _fields) {
      final variable = draft.type.size == null;
      final bits = draft.bits.text.trim();
      final ranged = draft.type.unsigned && bits.isNotEmpty;
      fields.add(
        AdvertisementField(
          draft.name.text.trim(),
          int.tryParse(draft.offset.text.trim())!,
          draft.type,
          length: variable ? int.tryParse(draft.length.text.trim())! : 1,
          scale: variable ? 1 : double.tryParse(draft.scale.text.trim())!,
          add: variable ? 0 : double.tryParse(draft.add.text.trim())!,
          unit: draft.unit.text.trim(),
          record: _records ? _hexNumber(draft.record.text) : null,
          bit: ranged ? int.tryParse(draft.bit.text.trim())! : 0,
          bits: ranged ? int.tryParse(bits) : null,
        ),
      );
    }
    RecordFormat? records;
    if (_records) {
      records = RecordFormat(
        offset: int.tryParse(_recordOffset.text.trim())!,
        type: _recordType,
        length: _recordLength,
      );
    }
    // This codec is the sole throwing input parser; unexpected construction errors propagate.
    List<int> match;
    try {
      match = PayloadCodec.decode(_match.text, hex: true);
    } on FormatException {
      return null;
    }
    return AdvertisementParser(
      name: _name.text.trim(),
      source: _source,
      companyId: _source == AdvertisementSource.manufacturer ? _companyId : null,
      serviceUuid: _source == AdvertisementSource.service ? _serviceUuid : null,
      match: List.unmodifiable(match),
      matchOffset: int.tryParse(_matchOffset.text.trim())!,
      records: records,
      device: _deviceOnly ? _device : null,
      fields: List.unmodifiable(fields),
    );
  }

  void _removeField(ParserFieldDraft draft) {
    setState(() => _fieldForms.removeAt(_fields.indexOf(draft)));
    WidgetsBinding.instance.addPostFrameCallback((_) => draft.dispose());
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
                if (_form.valid && parser != null) {
                  Navigator.pop(context, parser);
                  return;
                }
                _form.markAllAsTouched();
              },
              child: const Text('Save parser'),
            ),
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
              decoration: const InputDecoration(labelText: 'Parser name', hintText: 'My sensor'),
              validationMessages: inputValidationMessages,
            ),
            const SizedBox(height: 16),
            SegmentedButton<AdvertisementSource>(
              segments: [
                for (final source in AdvertisementSource.values)
                  ButtonSegment(value: source, label: Text(source.label)),
              ],
              selected: {_source},
              onSelectionChanged: (value) {
                return setState(() {
                  _source = value.single;
                  _key.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                if (_source == AdvertisementSource.manufacturer) {
                  return ReactiveTextField<String>(
                    key: ObjectKey(_key),
                    formControl: _key,
                    decoration: const InputDecoration(labelText: 'Company ID (hex)', hintText: '0xFFFF'),
                    validationMessages: inputValidationMessages,
                  );
                }
                return ReactiveTextField<String>(
                  key: ObjectKey(_key),
                  formControl: _key,
                  decoration: const InputDecoration(labelText: 'Service UUID', hintText: '180f'),
                  validationMessages: inputValidationMessages,
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Sample from this device', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                if (sample == null) {
                  return Text(
                    'The latest advertisement has no payload for this source. '
                    'Offsets count from the first byte after the company ID.',
                    style: Theme.of(context).textTheme.bodySmall,
                  );
                }
                return Wrap(
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
                );
              },
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
                  child: ReactiveTextField<String>(
                    key: ObjectKey(_matchOffset),
                    formControl: _matchOffset,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'At offset'),
                    validationMessages: inputValidationMessages,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReactiveTextField<String>(
                    key: ObjectKey(_match),
                    formControl: _match,
                    decoration: const InputDecoration(labelText: 'Bytes (hex)', hintText: '01'),
                    validationMessages: inputValidationMessages,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Layout', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Fixed offsets read every field at its position. Records split the payload into type–length–value '
              'records, as in BTHome; fields then name their record type.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Fixed offsets')),
                ButtonSegment(value: true, label: Text('Records')),
              ],
              selected: {_records},
              onSelectionChanged: (value) => setState(() => _records = value.single),
            ),
            if (_records) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 140,
                    child: ReactiveTextField<String>(
                      key: ObjectKey(_recordOffset),
                      formControl: _recordOffset,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Records start at'),
                      validationMessages: inputValidationMessages,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: ReactiveDropdownField<RecordTypeFormat>(
                      key: ObjectKey(_recordTypeControl),
                      formControl: _recordTypeControl,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Record type'),
                      items: [
                        for (final type in RecordTypeFormat.values)
                          DropdownMenuItem(value: type, child: Text(type.label)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: ReactiveDropdownField<RecordLength>(
                      key: ObjectKey(_recordLengthControl),
                      formControl: _recordLengthControl,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Record layout'),
                      items: [
                        for (final length in RecordLength.values)
                          DropdownMenuItem(value: length, child: Text(length.label)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
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
            for (final draft in _fields) ...[
              const SizedBox(height: 12),
              ParserFieldCard(
                key: ObjectKey(draft),
                draft: draft,
                records: _records,
                recordType: _recordType,
                onRemove: _fields.length > 1 ? () => _removeField(draft) : null,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(() => _fieldForms.add(ParserFieldDraft())),
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
}

/// A nested form group preserves partially typed numeric input.
class ParserFieldDraft() extends FormGroup {
  this
    : super({
        'name': FormControl<String>(value: ''),
        'offset': FormControl<String>(value: '0'),
        'length': FormControl<String>(value: '1'),
        'scale': FormControl<String>(value: '1'),
        'add': FormControl<String>(value: '0'),
        'unit': FormControl<String>(value: ''),
        'record': FormControl<String>(value: ''),
        'bit': FormControl<String>(value: '0'),
        'bits': FormControl<String>(value: ''),
        'type': FormControl<AdvertisementFieldType>(value: AdvertisementFieldType.uint8),
      });
  FormControl<String> get name => control('name') as FormControl<String>;
  FormControl<String> get offset => control('offset') as FormControl<String>;
  FormControl<String> get length => control('length') as FormControl<String>;
  FormControl<String> get scale => control('scale') as FormControl<String>;
  FormControl<String> get add => control('add') as FormControl<String>;
  FormControl<String> get unit => control('unit') as FormControl<String>;
  FormControl<String> get record => control('record') as FormControl<String>;
  FormControl<String> get bit => control('bit') as FormControl<String>;
  FormControl<String> get bits => control('bits') as FormControl<String>;
  FormControl<AdvertisementFieldType> get typeControl => control('type') as FormControl<AdvertisementFieldType>;
  AdvertisementFieldType get type => typeControl.value!;
  set type(AdvertisementFieldType value) => typeControl.value = value;
}

String? _required(String value) => value.trim().isEmpty ? 'Enter a name.' : null;

String _companyText(int id) => '0x${id.toRadixString(16).padLeft(4, '0').toUpperCase()}';

String _number(double value) => value == value.roundToDouble() ? '${value.toInt()}' : '$value';

int? _hexNumber(String text) => int.tryParse(text.trim().replaceFirst(RegExp('^0[xX]'), ''), radix: 16);

String? _offsetError(String? value) {
  final offset = int.tryParse(value?.trim() ?? '');
  return offset == null || offset < 0 ? 'Enter 0 or more.' : null;
}

/// One keyed field card within ParserEditorPage; its page owns the draft controllers.
class const ParserFieldCard({
  super.key,
  required final ParserFieldDraft draft,
  required final bool records,
  required final RecordTypeFormat recordType,
  required final VoidCallback? onRemove,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final variable = draft.type.size == null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ReactiveTextField<String>(
                    key: ObjectKey(draft.name),
                    formControl: draft.name,
                    decoration: const InputDecoration(labelText: 'Field name', hintText: 'Temperature'),
                    validationMessages: inputValidationMessages,
                  ),
                ),
                IconButton(tooltip: 'Remove field', onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (records)
                  SizedBox(
                    width: 140,
                    child: ReactiveTextField<String>(
                      key: ObjectKey(draft.record),
                      formControl: draft.record,
                      decoration: const InputDecoration(labelText: 'Record type (hex)', hintText: '02'),
                      validationMessages: inputValidationMessages,
                    ),
                  ),
                SizedBox(
                  width: records ? 140 : 96,
                  child: ReactiveTextField<String>(
                    key: ObjectKey(draft.offset),
                    formControl: draft.offset,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: records ? 'Offset in value' : 'Offset'),
                    validationMessages: inputValidationMessages,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: ReactiveDropdownField<AdvertisementFieldType>(
                    key: ObjectKey(draft.typeControl),
                    formControl: draft.typeControl,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [
                      for (final type in AdvertisementFieldType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                  ),
                ),
                if (draft.type.unsigned) ...[
                  SizedBox(
                    width: 96,
                    child: ReactiveTextField<String>(
                      key: ObjectKey(draft.bit),
                      formControl: draft.bit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Bit offset'),
                      validationMessages: inputValidationMessages,
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: ReactiveTextField<String>(
                      key: ObjectKey(draft.bits),
                      formControl: draft.bits,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Bit count', hintText: 'All'),
                      validationMessages: inputValidationMessages,
                    ),
                  ),
                ],
                Builder(
                  builder: (context) {
                    if (variable) {
                      return SizedBox(
                        width: 96,
                        child: ReactiveTextField<String>(
                          key: ObjectKey(draft.length),
                          formControl: draft.length,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Bytes'),
                          validationMessages: inputValidationMessages,
                        ),
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 96,
                          child: ReactiveTextField<String>(
                            key: ObjectKey(draft.scale),
                            formControl: draft.scale,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(labelText: 'Scale'),
                            validationMessages: inputValidationMessages,
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: ReactiveTextField<String>(
                            key: ObjectKey(draft.add),
                            formControl: draft.add,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(labelText: 'Add'),
                            validationMessages: inputValidationMessages,
                          ),
                        ),
                        SizedBox(
                          width: 96,
                          child: ReactiveTextField<String>(
                            key: ObjectKey(draft.unit),
                            formControl: draft.unit,
                            decoration: const InputDecoration(labelText: 'Unit', hintText: '°C'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
