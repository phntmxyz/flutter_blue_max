import 'package:flutter_blue_max_example/advertisements/advertisement_parser.dart';
import 'package:flutter_blue_max_example/shared/stored_list.dart';

/// Parsers are stored as JSON in the platform's preferences, which is local storage on the web.
const parserStoreKey = 'advertisement_parsers';

/// Null until parsers were saved once, so first launches can start with examples.
Future<StoredList<AdvertisementParser>?> loadParsers() => loadStoredList(parserStoreKey, AdvertisementParser.fromJson);

/// Keeps the [unreadable] entries of the last load, so saving never drops them.
Future<void> saveParsers(List<AdvertisementParser> parsers, {List<Object?> unreadable = const []}) =>
    saveStoredList(parserStoreKey, parsers, unreadable: unreadable);
