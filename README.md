Redstone.dart
=========

[![Build Status](https://drone.io/github.com/luizmineo/redstone.dart/status.png)](https://drone.io/github.com/luizmineo/redstone.dart/latest)

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

####Want to know more?
Check out our [wiki](https://github.com/luizmineo/redstone.dart/wiki)! :)
