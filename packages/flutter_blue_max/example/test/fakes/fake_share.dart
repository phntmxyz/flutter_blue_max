import "package:share_plus_platform_interface/share_plus_platform_interface.dart";

/// Replaces the native share sheet and records what was shared.
final class FakeShare() extends SharePlatform {
  final shared = <ShareParams>[];

  Future<ShareResult> Function(ShareParams params)? overrideShare;

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    final override = overrideShare;
    if (override != null) {
      return await override(params);
    }
    return const ShareResult("fake", ShareResultStatus.success);
  }
}
