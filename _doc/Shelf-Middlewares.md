---
layout: doc
menu_item: doc
title: Shelf Middlewares
prev: Plugin-API
next: Unit-test
---
Since v0.5, Redstone.dart is built around the [Shelf](http://pub.dartlang.org/packages/shelf) framework. That means you can use any Shelf middleware or handler in your app:

```dart

main() {
  //Middlewares registered with addShelfMiddleware() will be invoked before
  //any interceptor or route.
  app.addShelfMiddleware(...);
  app.addShelfMiddleware(...);
  
  //The handler registered with setShelfHandler() will be invoked when all
  //interceptors are completed, and there is no route for the requested URL.
  app.setShelfHandler(...);

  app.setupConsoleLog();
  app.start();

}

```

For example, you can use [shelf_static](http://pub.dartlang.org/packages/shelf_static) to serve static files:

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