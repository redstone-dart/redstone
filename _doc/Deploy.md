---
layout: doc
menu_item: doc
title: Deploy
prev: Server-Configuration
next: redstone_mapper
---
The easiest way to build your app is using the [grinder](http://pub.dartlang.org/packages/grinder) library. Redstone.dart provides a simple task to properly copy the server's files to the build folder, which you can use in your build script. Example:

* Create a `build.dart` file inside the `bin` folder

```dart
import 'package:grinder/grinder.dart';
import 'package:grinder/grinder_utils.dart';
import 'package:redstone/tasks.dart';

main(List<String> args) {
  defineTask('build', taskFunction: (GrinderContext ctx) => new PubTools().build(ctx));
  defineTask('deploy_server', taskFunction: deployServer, depends: ['build']);
  defineTask('all', depends: ['build', 'deploy_server']);
  
  startGrinder(args);
}
```

* Instead of running `pub build` directly, you can call `build.dart` to properly build your app.

* To run `build.dart` through Dart Editor, you need to create a command-line launch configuration, with the following parameters:

Parameter         | Value
------------------|----------
Dart Script       | bin/build.dart
Working directory | (root path of your project)
Script arguments  | all

* To run `build.dart` through command line, you need to set the DART_SDK environment variable:

```
$ export DART_SDK=(path to dart-sdk)
$ dart bin/build.dart all
```

##DartVoid

If you plan to deploy your app at [DartVoid](http://www.dartvoid.com/), you won't need a build script (since DartVoid will manage the deploy for you), but you will need to split your app in two projects: `server` and `client`.

DartVoid already provides a set of app templates built with several framework, including Redstone.dart, which you can use to bootstrap your app:

* [Hello World](https://github.com/DartTemplates/Redstone-Hello)
* [Guestbook](https://github.com/DartTemplates/Redstone-Guestbook)
* [Todo List](https://github.com/DartTemplates/Redstone-Angular-Todo)