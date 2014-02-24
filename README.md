bloodless
=========

A microframework for Dart, heavily inspired by [Flask](http://flask.pocoo.org/).

```dart

import 'package:bloodless/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

main() {

  app.setupConsoleLog();
  app.start();
  
}

```

```
$ dart hello.dart 
INFO: 2014-02-24 13:16:19.086: Configured target for / : .helloWorld
INFO: 2014-02-24 13:16:19.102: Setting up VirtualDirectory for /home/user/project/web - index files: [index.html]
INFO: 2014-02-24 13:16:19.121: Running on 0.0.0.0:8080
```

# Installation

**NOTE: It's recommended to use Dart 1.2 or above, which is currently available only at the [dev channel](http://gsdview.appspot.com/dart-archive/channels/dev/release/latest/) (bloodless works better with the [new layout of build directory](https://groups.google.com/a/dartlang.org/forum/?fromgroups#!topic/announce/JjilMA9pQXE)).**

* Create a new Dart package ([manually](http://pub.dartlang.org/doc/) or through Dart Editor)
* Add bloodless as a dependency in `pubspec.yaml` file

```
name: my_app
 dependencies:
   bloodless: any
```
- Run `pub get` to update dependencies
- Create a `bin` directory
- Create a `server.dart` file under the `bin` directory

```dart

import 'package:bloodless/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

main() {

  app.setupConsoleLog();
  app.start();
  
}

```

- To run the server, create a launch configuration in Dart Editor, or use the `dart` command:

```
$ dart bin/server.dart
INFO: 2014-02-24 13:16:19.086: Configured target for / : .helloWorld
INFO: 2014-02-24 13:16:19.102: Setting up VirtualDirectory for /home/user/project/web - index files: [index.html]
INFO: 2014-02-24 13:16:19.121: Running on 0.0.0.0:8080
```

# Routing

## Retrieving path parameters

## Retrieving query parameters

## HTTP Methods

## Retrieving request's body

## The request object

# Interceptors

# Groups

# Error handlers

# Configuring the server

