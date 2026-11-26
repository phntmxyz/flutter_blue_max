import "package:collection/collection.dart";
import "package:context_plus/context_plus.dart";
import "package:flutter/widgets.dart";
import "package:flutter_blue_max_example/advertisements/parser_library.dart";
import "package:flutter_blue_max_example/app/workbench_controller.dart";
import "package:flutter_blue_max_example/gatt/gatt_catalog_library.dart";

final workbenchRef = Ref<WorkbenchController>();
final parserLibraryRef = Ref<ParserLibrary>();
final catalogLibraryRef = Ref<GattCatalogLibrary>();

/// Shares app- or caller-owned state with the navigator and its routes.
class const WorkbenchScope({super.key, required final WorkbenchController controller, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ContextPlus.root(
    key: ObjectKey(controller),
    child: Builder(
      builder: (context) {
        workbenchRef.bindValue(context, controller);
        parserLibraryRef.bindValue(context, controller.parserLibrary);
        catalogLibraryRef.bindValue(context, controller.catalogLibrary);
        return child;
      },
    ),
  );
}

extension WorkbenchSnapshotSelection<T extends Listenable> on ReadOnlyRef<T> {
  /// Compare panel snapshots, including nested channel histories, by contents.
  void watchSnapshot(BuildContext context, List<Object?> Function(T) select) {
    watchOnly(context, (source) => _Snapshot(select(source)));
  }
}

class const _Snapshot(final List<Object?> values) {
  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) => other is _Snapshot && _equality.equals(values, other.values);

  @override
  int get hashCode => _equality.hash(values);
}
