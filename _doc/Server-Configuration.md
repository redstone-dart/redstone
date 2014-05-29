---
layout: doc
menu_item: doc
title: Server Configuration
prev: Unit-test
next: Deploy
---
If you invoke the `start()` method with no arguments, the server will be configured with default values:

Argument       | Default Value
---------------|---------------
host           | "0.0.0.0"
port           | 8080

## Static Files

If you need to serve static files, you can use the [shelf_static](http://pub.dartlang.org/packages/shelf_static) package:

```dart
import 'package:redstone/server.dart' as app;
import 'package:shelf_static/shelf_static.dart';

main() {
  app.setShelfHandler(createStaticHandler("../web", 
                                          defaultDocument: "index.html", 
                                          serveFilesOutsidePath: true));
  app.setupConsoleLog();
  app.start();
}
```
## Logging

Redstone.dart provides a helper method to set a simple log handler, which outputs the messages to the console:

```dart
app.setupConsoleLog();
```

By default, the log level is setted to INFO, which logs the startup process and errors. If you want to see all the log messages, you can set the level to ALL:

```dart
import 'package:logging/logging.dart';


main() {
  app.setupConsoleLog(Level.ALL);
  ...
}
```

If you want to output the messages to a different place (for example, a file), you can define your own log handler:

```dart
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((LogRecord rec) {
  ...
});
```