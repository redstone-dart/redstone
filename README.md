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

## Installation

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

- Now head over to http://127.0.0.1:8080/, and you should see your hello world greeting.

## Routing

Just use the `Route` annotation to bind a method with a URL:

```Dart
@app.Route("/")
helloWorld() => "Hello, World!";
```

The returned value will be serialized to the client according to its type. For example, if the value is a String, the client will receive a *text/plain* response.

Returned Value | Response type
---------------|---------------
String         | text/plain
Map or List    | application/json
File           | (MimeType of the file)

If a Future is returned, then the framework will wait for its completion. 

 ```Dart
@app.Route("/")
helloWorld() => new Future(() => "Hello, World!");
```

For other types, bloodless will convert the value to a String, and send it as *text/plain*.

Also, it's possible to override the content type of the response:

```Dart
@app.Route("/", responseType: "text/xml")
getXml() => "<root><node>text</node></root>";
```

### Retrieving path parameters

You can easily bind URL parts to arguments:

```Dart
@app.Route("/user/:username")
helloUser(String username) => "hello $username";
```

The argument doesn't need to be a String. If it's an int, for example, bloodless will try to convert the value for you (if the conversion fails, a 400 status code is sent to the client).

```Dart
@app.Route("/user/:username/:addressId")
getAddress(String username, int addressId) {
  ...
};
```

The supported types are: int, double and bool

### Retrieving query parameters

Use the `QueryParam` annotation to access a query parameter

```Dart
@app.Route("/user")
getUser(@app.QueryParam("id") int userId) {
  ...
};
```

Like path parameters, the argument doesn't need to be a String. 

### HTTP Methods

By default, a route only respond to GET requests. You can change that with the `methods` arguments:

```Dart
@app.Route("/user/:username", methods: const [app.GET, app.POST])
helloUser(String username) => "hello $username";
```

### Retrieving request's body

You can retrieve the requests's body as a form, json or text

```Dart
@app.Route("/adduser", methods: const [app.POST])
addUser(@app.Body(app.JSON) Map json) {
  ...
};
```

```Dart
@app.Route("/adduser", methods: const [app.POST])
addUser(@app.Body(app.FORM) Map form) {
  ...
};
```

### The request object

You can use the global `request` object to access the request's information and content:

```Dart
@app.Route("/user", methods: const [app.GET, app.POST])
user() {
  if (app.request.method == app.GET) {
    ...
  } else if (app.request.method == app.POST) {
    
    if (app.request.bodyType == app.JSON) {
      var json = app.request.body;
      ...
    } else {
      ...
    }
  }
};
```

Actually, the `request` object is a get method, that retrieves the request object from the current Zone. Since each request runs in its own zone, it's completely safe to use `request` at any time, even in async callbacks.

## Interceptors

Each request is actually a chain, composed by 0 or more interceptors, and a target. A target is a method annotated with `Route`, or a static file handled by a VirtualDirectory instance. An interceptor is a structure that allows you to apply a common behaviour to a group of targets. For example, you can use a interceptor to change the response of a group of targets, or to apply a security constraint.

```Dart
@app.Interceptor(r'/.*')
handleResponseHeader() {
  app.request.response.headers.add("Access-Control-Allow-Origin", "*");
  app.chain.next();
}
```

```Dart
@app.Interceptor(r'/admin/.*')
adminFilter() {
  if (app.request.session["username"] != null) {
    app.chain.next();
  } else {
    app.chain.interrupt(HttpStatus.UNAUTHORIZED);
    //or app.redirect("/login.html");
  }
}
```

When a request is received, the framework will execute all interceptors that matchs the URL, and then will look for a valid route. If a route is found, it will be executed, otherwise the request will be fowarded to the VirtualDirectory, which will look for a static file.

Each interceptor must execute the `chain.next()` or `chain.interrupt()` methods, otherwise, the request will be stucked. The `chain.next()` method returns a `Future`, that completes when the target completes. The interceptors are notified in the reverse order they are executed.

For example, consider this script:

```Dart
@app.Route("/")
helloWorld() => "target\n";

@app.Interceptor(r'/.*', chainIdx: 0)
interceptor1() {
  app.request.response.write("interceptor 1 - before target\n");
  app.chain.next().then((_) {
    app.request.response.write("interceptor 1 - after target\n");
  });
}

@app.Interceptor(r'/.*', chainIdx: 1)
interceptor2() {
  app.request.response.write("interceptor 2 - before target\n");
  app.chain.next().then((_) {
    app.request.response.write("interceptor 2 - after target\n");
  });
}

main() {

  app.setupConsoleLog();
  app.start();
  
}
```

When you access http://127.0.0.1:8080/, the result is:

```
interceptor 1 - before target
interceptor 2 - before target
target
interceptor 2 - after target
interceptor 1 - after target
```

Like the `request` object, the `chain` object is also a get method, that returns the chain of the current zone.

**NOTE: You can also call `redirect()` or `abort()` instead of `chain.interrupt()`. The `abort()` call will invoke the corresponding error handler.**

## Groups

You can use classes to group routes and interceptors:

```Dart
@Group("/user")
class UserService {
  
  @app.Route("/find")
  findUser(@app.QueryParam("n") String name,
           @app.QueryParam("c") String city) {
    ...
  }

  @app.Route("/add", methods: const [app.POST])
  addUser(@app.Body(app.JSON) Map json) {
    ...
  }
}
```

The prefix defined with the `Group` annotation, will be prepended in every route and interceptor inside the group.

**NOTE: The class must provide a default constructor, with no required arguments.**

## Error handlers

You can define error handlers with the `ErrorHandler` annotation:

```Dart
@app.ErrorHandler(HttpStatus.NOT_FOUND)
handleNotFoundError() => app.redirect("/error/not_found.html");
```

## Server configuration

If you invoke the `start()` method with no arguments, the server will be configured with default values:

Argument       | Default Value
---------------|---------------
host           | "0.0.0.0"
port           | 8080
staticDir      | "../web"
indexFiles     | ["index.html"]

## Logging

Bloodless provides a helper method to set a simple log handler, that outputs the messages to the console:

```Dart
app.setupConsoleLog();
```

By default, the log level is setted to INFO, which logs the startup process and errors. If you want to see all the log messages, you can set the level to ALL:

```Dart
import 'package:logging/logging.dart'

...

main() {
  ...
  app.setupConsoleLog(Level.ALL);
  ...
}
```

If you want to output the messages to a different locale (for example, a file), you can define your own log handler:

```Dart
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((LogRecord rec) {
  ...
});
```

## Deploying the app

When you run `pub build`, a `build` directory will be created with the following structure:

```
- build
  -- bin
     - server.dart
  -- web
     -- (static files)
```

Basically, the content of the `build` directory can be deployed in any server.

** NOTE: At least for now, the `pub build` command is creating the bin and web folders inside the build folder, but the .dart files inside bin are being filtered out. If you use Dart Editor, you can solve this by creating a `build.dart` file at the root of your project. **

```Dart
import "dart:io";

main() {
  Directory dir = new Directory("build/bin");
  dir.exists().then((exists) {
     if (exists) {
       File serverFile = new File("bin/server.dart");
       serverFile.copy("build/bin/server.dart");
     }
  }); 
}
```