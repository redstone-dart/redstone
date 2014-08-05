---
layout: doc
menu_item: doc
title: Importing Libraries
prev: Dependency-Injection
next: Plugin-API
---
Redstone.dart recursively scans all libraries imported by your main script. Example:

- server.dart

```dart
import 'package:redstone/server.dart' as app;
//all handlers in services.dart will be installed
import 'package:myapp/services.dart';

main() {
  app.setupConsoleLog();
  app.start();
}
``` 
- services.dart

```dart
import 'package:redstone/server.dart' as app;

@app.Route("/user/find")
findUser() {
  ...
}
```

However, sometimes you need more control on how handlers from other libraries are installed. In these cases, you can use the `@Install` annotation:

```dart
import 'package:redstone/server.dart' as app;
//all handlers in services.dart will be installed under the '/services' path
@app.Install(urlPrefix: '/services')
import 'package:myapp/services.dart';

main() {
  app.setupConsoleLog();
  app.start();
}
``` 

If the library defines interceptors, you can control the execution order:

```dart
import 'package:redstone/server.dart' as app;

@app.Install(chainIdx: 1)
import 'package:myapp/services.dart';

//this interceptor will be invoked first
@app.Interceptor("/.+", chainIdx: 0)
interceptor() {
  print("interceptor 1");
  app.chain.next();
}

main() {
  app.setupConsoleLog();
  app.start();
}
``` 
- services.dart

```dart
import 'package:redstone/server.dart' as app;

@app.Interceptor("/.+", chainIdx: 0)
interceptor() {
  print("interceptor 2");
  app.chain.next();
}

@app.Interceptor("/.+", chainIdx: 1)
interceptor2() {
  print("interceptor 3");
  app.chain.next();
}
```

If you want to import a library, but don't need its handlers, you can use the `@Ignore` annotation:

```dart
import 'package:redstone/server.dart' as app;
//handlers defined in services.dart won't be installed
@app.Ignore()
import 'package:myapp/services.dart';

main() {
  app.setupConsoleLog();
  app.start();
}
``` 

A library is installed only once. So, if you import the same library in different files, its handlers won't be installed twice:

```dart
import 'package:redstone/server.dart' as app;
import 'package:myapp/lib_a.dart';
import 'package:myapp/lib_b.dart';

main() {
  app.setupConsoleLog();
  app.start();
}
``` 
- lib_a.dart

```dart
library lib_a;
import 'package:redstone/server.dart' as app;
import 'package:myapp/lib_c.dart';

@app.Route(...)
serviceA() {
  ...
}
```
- lib_b.dart

```dart
library lib_b;
import 'package:redstone/server.dart' as app;
import 'package:myapp/lib_c.dart';

@app.Route(...)
serviceB() {
  ...
}
```
- lib_c.dart

```dart
//lib_c is imported by lib_a and lib_b, but its handlers are installed only once.
library lib_c;
import 'package:redstone/server.dart' as app;

@app.Interceptor(...)
interceptor() {
  ...
}
```