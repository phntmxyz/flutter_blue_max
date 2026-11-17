import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Shared, validated byte input for GATT writes and L2CAP transmissions.
class const PayloadEditor({
  super.key,
  required final Future<void> Function(List<int>) onSend,
  final bool enabled = true,

  /// Uses the FilledButton text style unless the supplied widget overrides it.
  final Widget label = const Text('Send payload'),
}) extends StatefulWidget {
  @override
  State<PayloadEditor> createState() => _PayloadEditorState();
}

class _PayloadEditorState() extends State<PayloadEditor> {
  final _form = FormGroup(
    {'payload': FormControl<String>(value: ''), 'hex': FormControl<bool>(value: true)},
    validators: [const _PayloadValidator()],
  );

  bool get _hex => _form.control('hex').value as bool;
  bool _sending = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_sending;
    final payload = _form.control('payload');
    if (enabled && payload.disabled) {
      payload.markAsEnabled(emitEvent: false);
    } else if (!enabled && payload.enabled) {
      payload.markAsDisabled(emitEvent: false);
    }
    return ReactiveForm(
      formGroup: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Hex')),
              ButtonSegment(value: false, label: Text('UTF-8')),
            ],
            selected: {_hex},
            onSelectionChanged: _sending ? null : (value) => setState(() => _form.control('hex').value = value.single),
          ),
          const SizedBox(height: 12),
          ReactiveTextField<String>(
            formControlName: 'payload',
            readOnly: !widget.enabled || _sending,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: 'Payload', hintText: _hex ? '01 A2 FF' : 'Hello from Blue Max'),
            validationMessages: {'payload': (error) => error as String},
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (() {
              if (!widget.enabled || _sending) {
                return null;
              }
              return () async {
                if (!_form.valid) {
                  _form.markAllAsTouched();
                  return;
                }
                setState(() => _sending = true);
                try {
                  await widget.onSend(
                    PayloadCodec.decode(_form.value['payload']! as String, hex: _form.value['hex']! as bool),
                  );
                } finally {
                  if (mounted) {
                    setState(() => _sending = false);
                  }
                }
              };
            })(),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: _sending ? const Text('Sending…') : widget.label,
          ),
        ],
      ),
    );
  }
}

/// Keeps payload validation in sync with either encoding or text changes.
class const _PayloadValidator() extends Validator<dynamic> {
  @override
  Map<String, dynamic>? validate(AbstractControl<dynamic> control) {
    final form = control as FormGroup;
    final payload = form.control('payload');
    String? message;
    try {
      if (PayloadCodec.decode(payload.value as String? ?? '', hex: form.control('hex').value as bool).isEmpty) {
        message = 'Enter a payload.';
      }
    } on FormatException catch (error) {
      message = error.message;
    }
    if (message == null) {
      payload.removeError('payload');
      return null;
    }
    payload.setErrors({'payload': message}, markAsDirty: false);
    return null;
  }
}
