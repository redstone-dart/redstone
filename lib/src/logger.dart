part of bloodless_server;

final Logger _logger = new Logger("bloodless_server");

/// Setup a simple log handler, that output messages to console.
void setupConsoleLog([Level level = Level.INFO]) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((LogRecord rec) {
    if (rec.level >= Level.SEVERE) {
      print('${rec.level.name}: ${rec.time}: ${rec.message} - ${rec.error}');
    } else {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
    }
  });
}