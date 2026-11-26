import "package:flutter/foundation.dart";
import "package:flutter_blue_max_example/shared/stored_list.dart";

/// App-lifetime list state shared by parser and catalog libraries, independent of Bluetooth.
/// Every mutation awaits loading, and writes serialize immutable snapshots while retaining unreadable entries.
class PersistedLibrary<T>({
  required final String key,
  required final String label,
  required final String resetAction,
  required final String resetNoun,
  required final Future<StoredList<T>?> Function() read,
  required final void Function(LibraryProblem problem) onProblem,
  final List<T> defaults = const [],
  final Future<void> Function(String key, List<Object?> items, {List<Object?> unreadable}) write = saveStoredList,
}) extends ChangeNotifier {
  final _items = <T>[];
  List<Object?> _unreadable = const [];
  bool _storeUnreadable = false;
  bool _disposed = false;
  bool _hasLoaded = false;
  late final Future<void> _loaded = _load();
  Future<void> _writes = Future.value();

  List<T> get items => List.unmodifiable(_items);
  Future<void> load() => _loaded;

  Future<void> _load() async {
    try {
      final stored = await read();
      _items.addAll(stored?.items ?? defaults);
      _unreadable = stored?.unreadable ?? const [];
      if (_unreadable.isNotEmpty) {
        final entries = _unreadable.length == 1 ? "1 stored entry" : "${_unreadable.length} stored entries";
        onProblem(
          LibraryProblem(
            "Loading $label: $entries could not be read and stay stored unchanged. "
                '$resetAction removes them. ${stored?.problem?.message ?? ''}',
            "ERROR loading $label: $entries unreadable: ${stored?.problem?.message}",
            error: stored?.problem,
            stackTrace: stored?.problemStack,
          ),
        );
      }
    } catch (exception, stackTrace) {
      _storeUnreadable = true;
      onProblem(
        LibraryProblem(
          "Loading $label: $exception\nChanges are not saved until you reset the $resetNoun.",
          "ERROR loading $label: $exception",
          error: exception,
          stackTrace: stackTrace,
        ),
      );
    }
    _hasLoaded = true;
    _notify();
  }

  Future<void> save(T item, {T? previous}) => change((items) {
    final index = previous == null ? -1 : items.indexOf(previous);
    if (index < 0) {
      items.add(item);
    } else {
      items[index] = item;
    }
  });

  Future<void> remove(T item) => change((items) {
    items.remove(item);
  });

  /// Restores defaults and discards entries that could not be decoded.
  /// Use only after the user agrees to replace an unreadable or newer-format library.
  Future<void> reset() async {
    if (!_hasLoaded) {
      await load();
    }
    _items
      ..clear()
      ..addAll(defaults);
    _unreadable = const [];
    _storeUnreadable = false;
    await _persist();
  }

  /// Feature-specific import policy can change the list only after its initial load.
  Future<LibraryChange<R>> change<R>(R Function(List<T> items) action) async {
    if (!_hasLoaded) {
      await load();
    }
    final result = action(_items);
    final saved = await _persist();
    return LibraryChange(result, saved: saved);
  }

  Future<bool> _persist() {
    if (_storeUnreadable) {
      _notify();
      onProblem(
        LibraryProblem(
          "Saving $label: the stored $label could not be read, so changes are not saved. $resetAction replaces them.",
          "ERROR saving $label: stored value unreadable",
        ),
      );
      return Future.value(false);
    }
    final snapshot = List<Object?>.of(_items);
    final unreadable = List<Object?>.of(_unreadable);
    final saved = _writes.then((_) async {
      try {
        await write(key, snapshot, unreadable: unreadable);
        return true;
      } catch (exception, stackTrace) {
        onProblem(
          LibraryProblem(
            "Saving $label: $exception",
            "ERROR saving $label: $exception",
            error: exception,
            stackTrace: stackTrace,
          ),
        );
        return false;
      }
    });
    _writes = saved;
    _notify();
    return saved;
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// An in-memory change and whether its snapshot was written to storage.
class const LibraryChange<R>(final R value, {required final bool saved});

/// Error state for the shell and activity log without coupling storage to a Bluetooth controller.
class const LibraryProblem(
  final String message,
  final String activity, {
  final Object? error,
  final StackTrace? stackTrace,
});
