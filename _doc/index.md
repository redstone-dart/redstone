---
layout: doc
menu_item: doc
title: Introduction
next: Installation
---
Redstone.dart is a server-side, metadata driven microframework for [Dart](https://www.dartlang.org/). 

####How does it work?
Redstone.dart allows you to easily publish your functions and classes through a web interface, by just adding some annotations to them. 

```dart

import 'package:redstone/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

main() {
  app.setupConsoleLog();
  app.start();
}
``` 
Does this example look familiar? Redstone.dart took a lot of ideas and concepts from the Python's [Flask](http://flask.pocoo.org/) microframework.
