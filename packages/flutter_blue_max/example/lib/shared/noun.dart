/// Singular and plural forms for counts, labels, and messages.
class const Noun({required final String singular, required final String plural});

/// E.g. "1 parser" or "3 parsers".
String counted(int count, Noun noun) => "$count ${count == 1 ? noun.singular : noun.plural}";
