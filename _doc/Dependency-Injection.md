---
layout: doc
menu_item: doc
title: Dependency Injection
prev: Groups
next: Importing-libraries
---
Redstone.dart uses the [di package](http://pub.dartlang.org/packages/di) to provide dependency injection.

To register a module, use the `addModule()` method:

```dart
import 'package:redstone/server.dart' as app;
import 'package:di/di.dart';

main() {

  app.addModule(new Module()
       ..bind(ClassA)
       ..bind(ClassB));
  
  app.setupConsoleLog();
  app.start();

}

```

For methods annotated with `@Route`, you can inject objects using the `@Inject` annotation:

```dart
@app.Route('/service')
service(@app.Inject() ClassA objA) {
 ...
}
```

Groups can require objects using a constructor:

```dart
@app.Group('/group')
class Group {

  ClassA objA;
  
  Group(ClassA this.objA);
  
  @app.Route('/service')
  service() {
    ...
  }

}
```

Interceptors and error handlers can also require dependencies:

```dart
@app.Interceptor(r'/services/.+')
interceptor(ClassA objA, ClassB objB) {
  ...
}


@app.ErrorHandler(404)
notFound(ClassB objB) {
  ...
}
```