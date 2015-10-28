---
layout: doc
menu_item: doc
title: Installation
prev: index
next: Feature-tour
---
Redstone.dart is available as a package at [pub](http://pub.dartlang.org/). So, all you have to do is add it as a dependency to your app.

* Create a new Dart package ([manually](http://pub.dartlang.org/doc/) or through WebStorm or [Stagehand's console application](http://stagehand.pub))
* Add Redstone.dart as a dependency in `pubspec.yaml` file and specify the [desired version](https://pub.dartlang.org/packages/redstone#installing)

```
name: my_app
 dependencies:
   redstone: any
```

- Run `pub get` to update dependencies
- Create a `bin` directory
- Create a `server.dart` file under the `bin` directory

```dart
import 'package:redstone/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

main() {
  app.setupConsoleLog();
  app.start();
}
```

- To run the server, create a launch configuration in WebStorm, or use the `dart` command:

```
$ dart bin/server.dart
INFO: 2014-02-24 13:16:19.086: Configured target for / [GET] : .helloWorld
INFO: 2014-02-24 13:16:19.121: Running on 0.0.0.0:8080
```

- Now head over to http://127.0.0.1:8080/, and you should see your hello world greeting.
