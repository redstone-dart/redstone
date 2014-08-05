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
protocol       | http

## Secure connections (https)

In order to start a secure server (https), you should specify the optional `secureOptions` argument
when calling the `start ()` method.

The `secureOptions` is a `Map<Symbol, dynamic>` that will be forwarded to the [`HttpServer.bindSecure()`](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/dart-io.HttpServer#id_bindSecure) method:

```dart
import 'package:redstone/server.dart' as app;

main() {
  app.setupConsoleLog();
  app.start(secureOptions: {#certificateName: "CN=RedStone"});
}
```

See the [`https.dart`](https://github.com/luizmineo/redstone.dart/blob/master/example/https.dart) for a working example.

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