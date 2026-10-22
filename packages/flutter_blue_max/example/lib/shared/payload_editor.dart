import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';

/// Shared, validated byte input for GATT writes and L2CAP transmissions.
class PayloadEditor extends StatefulWidget {
  const PayloadEditor({super.key, required this.onSend, this.enabled = true, this.label = const Text('Send payload')});

  final Future<void> Function(List<int>) onSend;
  final bool enabled;

  /// Uses the FilledButton text style unless the supplied widget overrides it.
  final Widget label;

  @override
  State<PayloadEditor> createState() => _PayloadEditorState();
}

class _PayloadEditorState extends State<PayloadEditor> {
  final _text = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _hex = true;
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Hex')),
              ButtonSegment(value: false, label: Text('UTF-8')),
            ],
            selected: {_hex},
            onSelectionChanged: _sending ? null : (value) => setState(() => _hex = value.single),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _text,
            enabled: widget.enabled && !_sending,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: 'Payload', hintText: _hex ? '01 A2 FF' : 'Hello from Blue Max'),
            validator: (value) {
              try {
                if (PayloadCodec.decode(value ?? '', hex: _hex).isEmpty) {
                  return 'Enter a payload.';
                }
              } on FormatException catch (error) {
                return error.message;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: (() {
              if (!widget.enabled || _sending) {
                return null;
              }
              return () async {
                if (!_form.currentState!.validate()) {
                  return;
                }
                setState(() => _sending = true);
                try {
                  await widget.onSend(PayloadCodec.decode(_text.text, hex: _hex));
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
