import "dart:typed_data";

import "package:flutter_blue_max/flutter_blue_max.dart";

/// Replaces only the Android-only operations that dart:io blocks on the VM test host.
/// Connection state and all other operations still use the real plugin and fake platform.
final class FakeAndroidDevice({required super.remoteId}) extends BluetoothDevice {
  final mtuRequests = <int>[];
  int bondRequests = 0;

  @override
  Future<int> requestMtu(int desiredMtu, {double predelay = 0.35, int timeout = 15}) async {
    mtuRequests.add(desiredMtu);
    return desiredMtu;
  }

  @override
  Future<void> createBond({int timeout = 90, Uint8List? pin}) async {
    bondRequests++;
  }
}
