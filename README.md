**Unfortunatelly, I won't be able to maintain this project (and any other open-source project) in the foreseeable future. I'm terrible sorry for this, and if you are relying on this code base for your project(s), please, accept my apologies.** 

**Also, if you have the interest, feel free to fork this repository and improve it. (for Redstone, you'll probably want to take a look at the v0.6 branch, which has a nicer code base).**

**For all you guys who have helped me improving this project, my sincere thanks.**

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
