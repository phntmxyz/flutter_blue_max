/// Verbosity of the logging of the platform layer, from silent to most verbose.
enum LogLevel {
  /// No logging.
  none,

  /// Log errors only.
  error,

  /// Log warnings and errors.
  warning,

  /// Log informational messages in addition.
  info,

  /// Log debug messages in addition.
  debug,

  /// Log everything.
  verbose,
}
