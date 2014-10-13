---
layout: doc
menu_item: doc
title: Deploy
prev: Server-Configuration
next: redstone_mapper
---
The easiest way to build your app is using the [Grinder](http://pub.dartlang.org/packages/grinder) build system. Redstone.dart provides a simple task to properly copy the server's files to the build folder, which you can use to create a build script.

**Note:** Since v0.5.18, Redstone.dart uses a new version of Grinder (v0.6.x), which includes some breaking changes. Also, with this new version, it's possible to invoke the build script using the `pub run` command. 

## Creating a build script

Create a `grind.dart` file inside the `tool` folder

### Redstone.dart v0.5.18 or above

```dart
import 'package:grinder/grinder.dart';
import 'package:redstone/tasks.dart';

main(List<String> args) {
  task('build', Pub.build);
  task('deploy_server', deployServer, ['build']);
  task('all', null, ['build', 'deploy_server']);

  startGrinder(args);
}
```

### Redstone.dart V0.5.17 or below

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

## Running the build script through DartEditor

To run `grind.dart` through Dart Editor, you need to create a command-line launch configuration, with the following parameters:

Parameter         | Value
------------------|----------
Dart Script       | tool/grind.dart
Working directory | (root path of your project)
Script arguments  | all

## Running the build script through command line

### Redstone.dart v0.5.18 or above

Just use the `pub run` command to invoke the build script (your `pubspec.yaml` file needs to include a dependency to the `grinder` package):

```
$ pub run grinder:grind all
```

If you install Grinder using [pub global](https://www.dartlang.org/tools/pub/cmd/pub-global.html), you can invoke `grind` directly:

```
$ grind all
```

### Redstone.dart V0.5.17 or below

To run `grind.dart` through command line, you need to set the DART_SDK environment variable:

```
$ export DART_SDK=(path to dart-sdk)
$ dart tool/grind.dart all
```

##DartVoid

If you plan to deploy your app at [DartVoid](http://www.dartvoid.com/), you won't need a build script (since DartVoid will manage the deploy for you), but you will need to split your app in two projects: `server` and `client`.

DartVoid already provides a set of app templates built with several frameworks, including Redstone.dart, which you can use to bootstrap your app:

* [Hello World](https://github.com/DartTemplates/Redstone-Hello)
* [Guestbook](https://github.com/DartTemplates/Redstone-Guestbook)
* [Todo List](https://github.com/DartTemplates/Redstone-Angular-Todo)