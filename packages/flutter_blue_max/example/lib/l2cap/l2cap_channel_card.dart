import 'package:flutter/material.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/l2cap/channel_session.dart';
import 'package:flutter_blue_max_example/shared/payload_codec.dart';
import 'package:flutter_blue_max_example/shared/payload_editor.dart';
import 'package:flutter_blue_max_example/shared/workbench_card.dart';

/// Exchanges data with the peer that owns this channel, regardless of selection.
class const L2capChannelCard({
  super.key,
  required final ChannelSession session,
  required final WorkbenchController controller,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WorkbenchCard(
      key: ValueKey(session.key),
      title: Text('${session.incoming ? 'Incoming' : 'Outgoing'} · PSM ${session.channel.psm}'),
      subtitle: Text(session.channel.deviceId.str),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              Chip(label: Text('TX ${session.transmitted} B')),
              Chip(label: Text('RX ${session.received} B')),
              if (session.closed) const Chip(label: Text('Closed')),
              if (!session.closed)
                OutlinedButton.icon(
                  onPressed: !controller.busy('channel:${session.key}') ? () => controller.readChannel(session) : null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Read buffered data'),
                ),
              if (!session.closed)
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
          ExpansionTile(
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            tilePadding: EdgeInsets.zero,
            title: const Text('Receive history'),
            subtitle: Text('${session.history.length} entries · buffer reads can repeat streamed bytes'),
            children: [
              for (final entry in session.history)
                ListTile(
                  title: Text('${entry.source} · ${entry.time.toIso8601String()} · ${entry.bytes.length} B'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(PayloadCodec.hex(entry.bytes)),
                      SelectableText(PayloadCodec.text(entry.bytes)),
                    ],
                  ),
                ),
            ],
          ),
          if (!session.closed) ...[
            const SizedBox(height: 16),
            PayloadEditor(
              enabled: !controller.busy('channel:${session.key}'),
              onSend: (bytes) => controller.send(session, bytes),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: (() {
                    if (controller.busy('channel:${session.key}')) {
                      return null;
                    }
                    return () => controller.sendTestTraffic(session, size: 10 * 1024, count: 1);
                  })(),
                  icon: const Icon(Icons.data_usage),
                  label: const Text('Send 10 KB'),
                ),
                OutlinedButton.icon(
                  onPressed: (() {
                    if (controller.busy('channel:${session.key}')) {
                      return null;
                    }
                    return () => controller.sendTestTraffic(session, size: 1024, count: 20);
                  })(),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Burst 20×1 KB'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
