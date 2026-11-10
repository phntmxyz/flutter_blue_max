/// Singular and plural of what is counted, e.g. ("parser", "parsers").
typedef Noun = (String, String);

/// E.g. "1 parser" or "3 parsers".
String counted(int count, Noun noun) => '$count ${count == 1 ? noun.$1 : noun.$2}';
