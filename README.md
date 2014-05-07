bloodless
=========

[![Build Status](https://drone.io/github.com/luizmineo/bloodless/status.png)](https://drone.io/github.com/luizmineo/bloodless/latest)

Bloodless is a server-side, metadata driven microframework for [Dart](https://www.dartlang.org/). 

####How does it work?
Bloodless allows you to easily publish your functions and classes through a web interface, by just adding some annotations to them. 

```dart

import 'package:bloodless/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

main() {
  app.setupConsoleLog();
  app.start();
}
``` 

####Want to know more?
Check out our [wiki](https://github.com/luizmineo/bloodless/wiki)! :)
