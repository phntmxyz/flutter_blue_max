import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_max/flutter_blue_max.dart';
import 'package:flutter_blue_max_example/activity/activity_panel.dart';
import 'package:flutter_blue_max_example/app/workbench_controller.dart';
import 'package:flutter_blue_max_example/devices/devices_panel.dart';
import 'package:flutter_blue_max_example/l2cap/l2cap_server_panel.dart';
import 'package:flutter_blue_max_example/library/library_panel.dart';

/// A responsive diagnostic app for the plugin's native and web backends.
class const WorkbenchApp({super.key, final WorkbenchController? controller}) extends StatefulWidget {
  @override
  State<WorkbenchApp> createState() => _WorkbenchAppState();
}

class _WorkbenchAppState() extends State<WorkbenchApp> {
  late final _controller = widget.controller ?? WorkbenchController();
  int _destination = 0;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFF207F75), brightness: brightness).copyWith(
      primary: dark ? const Color(0xFF85E3D1) : const Color(0xFF006B5E),
      surface: dark ? const Color(0xFF101820) : const Color(0xFFF6F8FA),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: colors.surface,
      appBarTheme: AppBarTheme(backgroundColor: colors.surface, centerTitle: false, toolbarHeight: 80, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: dark ? const Color(0xFF19242E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF101820) : const Color(0xFFF0F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16)),
      ),
      dividerTheme: DividerThemeData(color: colors.outlineVariant.withValues(alpha: 0.45)),
      // Expanded tiles otherwise draw lines flush against their header and last child.
      expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blue Max',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final c = _controller;
          final wide = MediaQuery.sizeOf(context).width >= 720;
          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.bluetooth_rounded),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Blue Max', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                      Text('Bluetooth workbench', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ],
              ),
              actions: [
                if (wide)
                  Chip(
                    avatar: () {
                      if (c.ready) {
                        return Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.primary);
                      }
                      return const Icon(Icons.circle_outlined, size: 10);
                    }(),
                    label: Text('Bluetooth ${c.adapter.name}'),
                  ),
                IconButton(
                  tooltip: 'Toggle light / dark theme',
                  onPressed: () {
                    setState(() => _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
                  },
                  icon: Icon(_themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                ),
                const SizedBox(width: 12),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  const Divider(height: 1),
                  if (!c.ready) _AdapterBanner(controller: c),
                  if (c.error != null)
                    Container(
                      width: double.infinity,
                      color: Theme.of(context).colorScheme.errorContainer,
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.error!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Dismiss error',
                            onPressed: c.dismissError,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        if (wide) ...[
                          NavigationRail(
                            selectedIndex: _destination,
                            onDestinationSelected: (index) => setState(() => _destination = index),
                            labelType: NavigationRailLabelType.all,
                            destinations: [
                              const NavigationRailDestination(icon: Icon(Icons.radar_rounded), label: Text('Devices')),
                              if (c.supportsL2cap)
                                const NavigationRailDestination(
                                  icon: Icon(Icons.dns_outlined),
                                  label: Text('Local server'),
                                ),
                              const NavigationRailDestination(
                                icon: Icon(Icons.local_library_outlined),
                                label: Text('Library'),
                              ),
                              const NavigationRailDestination(
                                icon: Icon(Icons.terminal_rounded),
                                label: Text('Activity'),
                              ),
                            ],
                          ),
                          const VerticalDivider(width: 1),
                        ],
                        Expanded(
                          child: IndexedStack(
                            index: _destination,
                            children: [
                              DevicesPanel(controller: c, active: _destination == 0),
                              if (c.supportsL2cap) L2capServerPanel(controller: c),
                              LibraryPanel(controller: c),
                              ActivityPanel(controller: c),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: (() {
              if (wide) {
                return null;
              }
              return NavigationBar(
                selectedIndex: _destination,
                onDestinationSelected: (index) => setState(() => _destination = index),
                destinations: [
                  const NavigationDestination(icon: Icon(Icons.radar_rounded), label: 'Devices'),
                  if (c.supportsL2cap)
                    const NavigationDestination(icon: Icon(Icons.dns_outlined), label: 'Local server'),
                  const NavigationDestination(icon: Icon(Icons.local_library_outlined), label: 'Library'),
                  const NavigationDestination(icon: Icon(Icons.terminal_rounded), label: 'Activity'),
                ],
              );
            })(),
          );
        },
      ),
    );
  }
}

class const _AdapterBanner({required final WorkbenchController controller}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final message = switch (controller.adapter) {
      BluetoothAdapterState.unknown when kIsWeb =>
        'Web Bluetooth is unavailable. Use a compatible browser over HTTPS or localhost and enable Bluetooth.',
      BluetoothAdapterState.unauthorized =>
        'Bluetooth permission is denied. Allow access in system settings, then reopen the app.',
      BluetoothAdapterState.unavailable => 'Bluetooth is not available on this device.',
      BluetoothAdapterState.off => 'Bluetooth is off. Enable it in system settings to scan or connect.',
      _ => 'Waiting for Bluetooth…',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
            // Only an off adapter needs the Android enable request.
            if (controller.adapter == BluetoothAdapterState.off)
              TextButton(
                onPressed: controller.busy('adapter') ? null : controller.turnOn,
                child: const Text('Turn on Bluetooth'),
              ),
          ],
        ],
      ),
    );
  }
}
