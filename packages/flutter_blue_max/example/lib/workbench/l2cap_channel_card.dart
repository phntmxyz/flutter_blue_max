import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/workbench/channel_session.dart';
import 'package:flutter_blue_max_example/workbench/payload_codec.dart';
import 'package:flutter_blue_max_example/workbench/payload_editor.dart';
import 'package:flutter_blue_max_example/workbench/workbench_card.dart';
import 'package:flutter_blue_max_example/workbench/workbench_controller.dart';

/// Exchanges data with the peer that owns this channel, regardless of selection.
class L2capChannelCard extends StatelessWidget {
  const L2capChannelCard({super.key, required this.session, required this.controller});

  final ChannelSession session;
  final WorkbenchController controller;

  @override
  Widget build(BuildContext context) {
    return WorkbenchCard(
      key: ValueKey(session.key),
      title: '${session.incoming ? 'Incoming' : 'Outgoing'} · PSM ${session.channel.psm}',
      subtitle: session.channel.deviceId.str,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(label: Text('TX ${session.transmitted} B')),
              Chip(label: Text('RX ${session.received} B')),
              TextButton.icon(
                onPressed: !controller.busy('channel:${session.key}') ? () => controller.closeChannel(session) : null,
                icon: const Icon(Icons.close),
                label: const Text('Close channel'),
              ),
            ],
          ),
          if (session.lastReceived.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Last received chunk'),
            SelectableText(PayloadCodec.hex(session.lastReceived), style: const TextStyle(fontFamily: 'monospace')),
            Text(PayloadCodec.text(session.lastReceived), maxLines: 4, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 16),
          PayloadEditor(
            enabled: !controller.busy('channel:${session.key}'),
            onSend: (bytes) => controller.send(session, bytes),
          ),
        ],
      ),
    );
  }
}
