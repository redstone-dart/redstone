# Redstone

[![Build Status](https://drone.io/github.com/luizmineo/redstone.dart/status.png)](https://drone.io/github.com/luizmineo/redstone.dart/latest)

Redstone is a server-side, metadata driven micro-framework for [Dart](https://www.dartlang.org/).

#### How does it work?
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

#### Want to know more?

Check out our [wiki](https://github.com/redstone-dart/redstone/wiki)! :)

#### History

Redstone.dart was created by [Luiz Henrique Farcic Mineo](https://github.com/luizmineo). On April 11th 2015, it was announced that Luiz would no longer be able to maintain this project. The community soon took to the issue tracker to plan a way to keep development up. Along with Luiz, decisions were made to put the entire project into the hands of the community.
