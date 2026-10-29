import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

/// Replaces the native share sheet and records what was shared.
final class FakeShare() extends SharePlatform {
  final shared = <ShareParams>[];

  @override
  Future<ShareResult> share(ShareParams params) async {
    shared.add(params);
    return const ShareResult('fake', ShareResultStatus.success);
  }
}
