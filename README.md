
# Redstone

[![Join the chat at https://gitter.im/redstone-dart/redstone](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/redstone-dart/redstone?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Build Status](https://travis-ci.org/redstone-dart/redstone.svg?branch=v0.5)](https://travis-ci.org/redstone-dart/redstone)

Redstone is an annotation driven web server micro-framework for [Dart](https://www.dartlang.org/) and influenced by [Flask](http://flask.pocoo.org/). It is based on [shelf](https://pub.dartlang.org/packages/shelf) so you may also use any shelf middleware you like with Redstone.

#### Example
Redstone allows you to easily publish functions through a web interface, by just adding some annotations to them.

```dart
import 'package:redstone/redstone.dart' as web;

@web.Route("/")
helloWorld() => "Hello, World!";

main() {
  web.setupConsoleLog();
  web.start();
}
```

#### Installation

To install, set the `redstone: "^0.6.4"` constraint to your pubspec.

```yaml
dependencies:
  redstone: "^0.6.4"
```
The following plugins are also available for this version:

```yaml
redstone_mapper: 0.2.0-beta.1+1
redstone_mapper_mongo: 0.2.0-beta.1
redstone_mapper_pg: 0.2.0-beta.2+2
redstone_web_socket: 0.1.0-beta.1
```

#### Want to learn more?

Check out our [wiki](https://github.com/redstone-dart/redstone/wiki)! :)
