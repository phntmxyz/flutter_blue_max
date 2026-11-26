import "package:context_plus/context_plus.dart";
import "package:flutter/material.dart";
import "package:flutter_blue_max_example/app/workbench_bindings.dart";
import "package:flutter_blue_max_example/app/workbench_controller.dart";
import "package:flutter_blue_max_example/l2cap/l2cap_channel_card.dart";
import "package:flutter_blue_max_example/shared/workbench_card.dart";

/// Local server destination in `WorkbenchApp`, available only on L2CAP platforms.
/// The receiving role waits for peers; it does not open a channel to a selected device.
class const L2capServerPanel({super.key}) extends StatefulWidget {
  @override
  State<L2capServerPanel> createState() => _L2capServerPanelState();
}

class _L2capServerPanelState() extends State<L2capServerPanel> {
  bool _secure = true;

  @override
  Widget build(BuildContext context) {
    workbenchRef.watchSnapshot(context, (c) => c.serverState);
    final c = workbenchRef.of(context);
    final incoming = c.channelSessions.where((s) => s.incoming).toList();
    final connectedCount = incoming.where((s) => !s.closed).length;
    final listenerControls = ServerListenerControls(
      psm: c.serverPsm,
      secure: _secure,
      busy: c.busy(Operation.server),
      ready: c.ready,
      onSecureChanged: (value) => setState(() => _secure = value),
      onStart: () => c.startServer(secure: _secure),
      onStop: c.stopServer,
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text("Accept incoming L2CAP connections", style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          "This device is the server. Another device opens the channel to it. "
          "To open a channel yourself, select a device in Devices and use its L2CAP tab.",
        ),
        const SizedBox(height: 24),
        ServerStatusCard(psm: c.serverPsm, connectedCount: connectedCount, child: listenerControls),
        const WorkbenchCard(
          title: Text("Connect from the other device"),
          icon: Icons.info_outline,
          child: Text(
            "The client needs to know this device and the assigned PSM. Starting this server does not advertise "
            "a discoverable GATT peripheral or exchange the PSM. Two copies of this example therefore cannot "
            "find and connect to each other automatically. Use a compatible peer that provides this setup. "
            "Android requires version 10 or newer.",
          ),
        ),
        if (incoming.isNotEmpty) ...[
          Text("Incoming channels", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (final session in incoming) L2capChannelCard(key: ValueKey(session.key), session: session),
        ],
      ],
    );
  }
}

/// Listener settings and start/stop controls in the Local server destination.
class const ServerListenerControls({
  super.key,
  required final int? psm,
  required final bool secure,
  required final bool busy,
  required final bool ready,
  required final ValueChanged<bool> onSecureChanged,
  required final VoidCallback onStart,
  required final VoidCallback onStop,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final canChangeServer = ready && !busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text("Require encryption"),
          value: secure,
          onChanged: psm == null && !busy ? onSecureChanged : null,
        ),
        if (psm != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SelectableText("PSM $psm", style: Theme.of(context).textTheme.headlineSmall)),
              IconButton(
                tooltip: "Copy server PSM",
                onPressed: () => workbenchRef.of(context).copyToClipboard("$psm"),
                icon: const Icon(Icons.copy),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Builder(
          builder: (_) {
            if (psm == null) {
              return FilledButton.icon(
                onPressed: canChangeServer ? onStart : null,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(busy ? "Working…" : "Start server"),
              );
            }
            return FilledButton.icon(
              onPressed: canChangeServer ? onStop : null,
              icon: const Icon(Icons.stop_rounded),
              label: Text(busy ? "Working…" : "Stop server"),
            );
          },
        ),
      ],
    );
  }
}

/// The preparation or active-listener card in Local server, including its incoming connection count.
class const ServerStatusCard({
  super.key,
  required final int? psm,
  required final int connectedCount,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (psm == null) {
      return WorkbenchCard(
        title: const Text("Prepare this device"),
        icon: Icons.dns_outlined,
        subtitle: const Text("Start listening before the other device connects."),
        child: child,
      );
    }
    final String status;
    if (connectedCount == 0) {
      status = "Waiting for a peer — no channel connected yet.";
    } else {
      status = '$connectedCount incoming ${connectedCount == 1 ? 'channel' : 'channels'} connected.';
    }
    return WorkbenchCard(
      title: Text("Listening on PSM $psm"),
      icon: Icons.dns_outlined,
      subtitle: Text(status),
      child: child,
    );
  }
}
