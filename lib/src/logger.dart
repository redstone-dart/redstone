library redstone.src.logger;

import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

final Logger redstoneLogger = new Logger("redstone_server");

/// Setup a simple log handler, that output messages to console.
void setupConsoleLog([Level level = Level.INFO]) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((LogRecord rec) {
    if (rec.level >= Level.SEVERE) {
      var stack =
          rec.stackTrace != null ? "\n${Trace.format(rec.stackTrace)}" : "";
      print(
          '${rec.level.name}: ${rec.time}: ${rec.message} - ${rec.error}${stack}');
    } else {
      print('${rec.level.name}: ${rec.time}: ${rec.message}');
    }
  });
}
