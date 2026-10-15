import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/l2cap/l2cap_channel_card.dart';
import 'package:flutter_blue_max_example/shared/workbench_card.dart';

/// The receiving role waits for peers; it does not open a channel to a selected device.
class L2capServerPanel extends StatefulWidget {
  const L2capServerPanel({super.key, required this.controller});
  final WorkbenchController controller;

  @override
  State<L2capServerPanel> createState() => _L2capServerPanelState();
}

class _L2capServerPanelState extends State<L2capServerPanel> {
  bool _secure = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final incoming = c.channels.where((session) => session.incoming).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Accept incoming L2CAP connections', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'This device is the server. Another device opens the channel to it. '
          'To open a channel yourself, select a device in Devices and use its L2CAP tab.',
        ),
        const SizedBox(height: 24),
        WorkbenchCard(
          title: c.serverPsm == null ? 'Prepare this device' : 'Listening on PSM ${c.serverPsm}',
          icon: Icons.dns_outlined,
          subtitle: c.serverPsm == null
              ? 'Start listening before the other device connects.'
              : incoming.isEmpty
              ? 'Waiting for a peer — no channel connected yet.'
              : '${incoming.length} incoming ${incoming.length == 1 ? 'channel' : 'channels'} connected.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require encryption'),
                value: _secure,
                onChanged: c.serverPsm == null && !c.busy('server') ? (value) => setState(() => _secure = value) : null,
              ),
              if (c.serverPsm != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText('PSM ${c.serverPsm}', style: Theme.of(context).textTheme.headlineSmall),
                    ),
                    IconButton(
                      tooltip: 'Copy server PSM',
                      onPressed: () => Clipboard.setData(ClipboardData(text: '${c.serverPsm}')),
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: c.ready && !c.busy('server')
                    ? () => c.serverPsm == null ? c.startServer(secure: _secure) : c.stopServer()
                    : null,
                icon: Icon(c.serverPsm == null ? Icons.play_arrow_rounded : Icons.stop_rounded),
                label: Text(
                  c.busy('server')
                      ? 'Working…'
                      : c.serverPsm == null
                      ? 'Start server'
                      : 'Stop server',
                ),
              ),
            ],
          ),
        ),
        const WorkbenchCard(
          title: 'Connect from the other device',
          icon: Icons.info_outline,
          child: Text(
            'The client needs to know this device and the assigned PSM. Starting this server does not advertise '
            'a discoverable GATT peripheral or exchange the PSM. Two copies of this example therefore cannot '
            'find and connect to each other automatically. Use a compatible peer that provides this setup. '
            'Android requires version 10 or newer.',
          ),
        ),
        if (incoming.isNotEmpty) ...[
          Text('Incoming channels', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final session in incoming) L2capChannelCard(key: ValueKey(session.key), session: session, controller: c),
        ],
      ],
    );
  }
}
