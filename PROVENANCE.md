# Source provenance

This document records the origin and licensing boundary of FlutterBlueMax. It is informational and does not replace the terms in [LICENSE](LICENSE).

## Project origin

FlutterBlueMax is an independent fork of [FlutterBluePlus][flutter-blue-plus]. The fork preserves the BSD 3-Clause license that applied to the FlutterBluePlus source code incorporated into this repository.

The latest upstream FlutterBluePlus release commit incorporated into the fork was:

- [`9427847747445448ed6f6cd8006dce906cef7cd0`][upstream-baseline] — `Release FBP 1.35.10` (September 6, 2025)

That upstream state was merged into the local L2CAP branch by:

- [`b9b4040153e5e5ea0e53f41f72ca3dae3806866a`][upstream-merge] — `Merge remote-tracking branch 'original/master' into l2cap-federated` (September 8, 2025)

## Recorded fork state

This initial provenance record covers the FlutterBlueMax history through:

- [`1f8d9c8944be8bad5b54ce4873879731d43c4355`][recorded-fork-state] — `Restore original Buffalo PC Inc. mention` (August 11, 2026)

## Upstream license boundary

The final FlutterBluePlus commit before its license change was:

- [`e4bd7a8db9a3df9aceeb6efd215f541e0e0f6a22`][last-bsd-commit] — `Update README.md` (September 17, 2025)

At that revision, FlutterBluePlus still used the BSD 3-Clause license. FlutterBluePlus changed to the FlutterBluePlus License in:

- [`a1e944cc325facb6d749a279950989101c0e83da`][license-change] — `Switch to FBP License` (September 21, 2025)

The later FlutterBluePlus license change does not alter the license previously granted for BSD-licensed revisions already incorporated into FlutterBlueMax.

## Upstream patch policy

- Code taken from a FlutterBluePlus revision before the license-change commit must be checked against the license and notices present in that revision.
- Copyrightable code introduced in or after the license-change commit must not be copied, translated, or cherry-picked into this BSD-licensed project unless every relevant copyright holder separately grants compatible permission.
- Public bug reports, release notes, protocol facts, and behavioral ideas may be used as input for an independent implementation. The implementation must not copy copyrightable expression from post-change FlutterBluePlus code.
- Every future upstream-derived patch should record its source commit and the license that applied to it.

FlutterBlueMax is maintained independently and is not affiliated with or endorsed by the FlutterBluePlus maintainers.

[flutter-blue-plus]: https://github.com/chipweinberger/flutter_blue_plus
[last-bsd-commit]: https://github.com/chipweinberger/flutter_blue_plus/commit/e4bd7a8db9a3df9aceeb6efd215f541e0e0f6a22
[license-change]: https://github.com/chipweinberger/flutter_blue_plus/commit/a1e944cc325facb6d749a279950989101c0e83da
[recorded-fork-state]: https://github.com/phntmxyz/flutter_blue_max/commit/1f8d9c8944be8bad5b54ce4873879731d43c4355
[upstream-baseline]: https://github.com/chipweinberger/flutter_blue_plus/commit/9427847747445448ed6f6cd8006dce906cef7cd0
[upstream-merge]: https://github.com/phntmxyz/flutter_blue_max/commit/b9b4040153e5e5ea0e53f41f72ca3dae3806866a
