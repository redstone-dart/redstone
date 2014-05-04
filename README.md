bloodless
=========

[![Build Status](https://drone.io/github.com/luizmineo/bloodless/status.png)](https://drone.io/github.com/luizmineo/bloodless/latest)

A metadata driven microframework for Dart.

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
INFO: 2014-02-24 13:16:19.102: Setting up VirtualDirectory for /home/user/project/web - followLinks: false - jailRoot: true - index files: [index.html]
INFO: 2014-02-24 13:16:19.121: Running on 0.0.0.0:8080
```

**NOTE: Bloodless took a lot of ideas and concepts from the Python's [Flask](http://flask.pocoo.org/) microframework**

## Installation

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
INFO: 2014-02-24 13:16:19.102: Setting up VirtualDirectory for /home/user/project/web - followLinks: false - jailRoot: true - index files: [index.html]
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

### Retrieving the request body

You can retrieve the request body as a form, json or text

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

#### Multipart requests (file uploads)

By default, Bloodless will refuse any multipart request. If your method need to receive a multipart request, you can set `Route.allowMultipartRequest = true`. Example:

```Dart
@app.Route("/adduser", methods: const [app.POST], allowMultipartRequest: true)
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
    app.chain.interrupt(statusCode: HttpStatus.UNAUTHORIZED);
    //or app.redirect("/login.html");
  }
}
```

When a request is received, the framework will execute all interceptors that matchs the URL, and then will look for a valid route. If a route is found, it will be executed, otherwise the request will be fowarded to the VirtualDirectory, which will look for a static file.

Each interceptor must call the `chain.next()` or `chain.interrupt()` methods, otherwise, the request will be stucked. The `chain.next()` method can receive a callback, that is executed when the target completes. All callbacks are executed in the reverse order they are created. If a callback returns a `Future`, then the next callback will execute only when the future completes.

For example, consider this script:

```Dart
@app.Route("/")
helloWorld() => "target\n";

@app.Interceptor(r'/.*', chainIdx: 0)
interceptor1() {
  app.request.response.write("interceptor 1 - before target\n");
  app.chain.next(() {
    app.request.response.write("interceptor 1 - after target\n");
  });
}

@app.Interceptor(r'/.*', chainIdx: 1)
interceptor2() {
  app.request.response.write("interceptor 2 - before target\n");
  app.chain.next(() {
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

**NOTE: By default, Bloodless won't parse the request body until all interceptors are called. If your interceptor need to inspect the request body, you must set `parseRequestBody = true`. Example:**

```Dart
@app.Interceptor(r'/service/.+', parseRequestBody: true)
verifyRequest() {
  //if parseRequestBody is not setted, request.body is null
  print(app.request.body);
  app.chain.next();
}

```


**NOTE: You can also call `redirect()` or `abort()` instead of `chain.interrupt()`. The `abort()` call will invoke the corresponding error handler.**

## Request attributes

Request attributes are objects that can be shared between interceptors and targets. They can be accessed through the `request.attributes` map. Also, if your method is annotated with `@Route`, they can be injected using the `Attr` annotation. Example:

```Dart

@app.Interceptor(r'/services/.+')
dbConnInterceptor() {
  var conn = new DbConn();
  app.request.attributes["dbConn"] = conn;
  app.chain.next(() => conn.close());
}

@app.Route('/services/find')
find(@app.Attr() dbConn) {
  ...
}

```

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

## Error handlers

You can define error handlers with the `ErrorHandler` annotation:

```Dart
@app.ErrorHandler(HttpStatus.NOT_FOUND)
handleNotFoundError() => app.redirect("/error/not_found.html");
```

Also, you can define a error handler for a specific urlPattern

```Dart
@app.ErrorHandler(HttpStatus.NOT_FOUND, urlPattern: r'/public/.+')
handleNotFoundError() => app.redirect("/error/not_found.html");
```

If you define a error handler inside a group, then the handler will be restricted to the group path.

**NOTE: If a target throws a error, it can be accessed through the `chain.error` getter.**

## Dependency injection

Bloodless uses the [di package](http://pub.dartlang.org/packages/di) to provide dependency injection.

To register a module, use the `addModule()` method:

```Dart
import 'package:bloodless/server.dart' as app;
import 'package:di/di.dart';

main() {

  app.addModule(new Module()
       ..bind(ClassA)
       ..bind(ClassB));
  
  app.setupConsoleLog();
  app.start();

}

```

For methods annotated with `@Route`, you can inject objects using the `@Inject` annotation:

```Dart
@app.Route('/service')
service(@app.Inject() ClassA objA) {
 ...
}
```

Groups can require objects using a constructor:

```Dart
@app.Group('/group')
class Group {

  ClassA objA;
  
  Group(ClassA this.objA);
  
  @app.Route('/service')
  service() {
    ...
  }

}
```

Interceptors and error handlers can also require dependencies:

```
@app.Interceptor(r'/services/.+')
interceptor(ClassA objA, ClassB objB) {
  ...
}


@app.ErrorHandler(404)
notFound(ClassB objB) {
  ...
}
```

## Server configuration

If you invoke the `start()` method with no arguments, the server will be configured with default values:

Argument       | Default Value
---------------|---------------
host           | "0.0.0.0"
port           | 8080
staticDir      | "../web"
indexFiles     | ["index.html"]
followLinks    | false
jailRoot       | true

**NOTE: During development, you will probably need to set `followLinks = true` and `jailRoot = false`, since Dartium will request for .dart files that are not in web folder. Although, doing so in production environment can lead to security issues.**

## Logging

Bloodless provides a helper method to set a simple log handler, that outputs the messages to the console:

```Dart
app.setupConsoleLog();
```

By default, the log level is setted to INFO, which logs the startup process and errors. If you want to see all the log messages, you can set the level to ALL:

```Dart
import 'package:logging/logging.dart';


main() {
  app.setupConsoleLog(Level.ALL);
  ...
}
```

If you want to output the messages to a different place (for example, a file), you can define your own log handler:

```Dart
Logger.root.level = Level.ALL;
Logger.root.onRecord.listen((LogRecord rec) {
  ...
});
```

## Unit tests

Bloodless provides a simple API that you can use to easily test your server. 

For example, consider you have the following service at `/lib/services.dart`

```Dart
library services;

import 'package:bloodless/server.dart' as app;

@app.Route("/user/:username")
helloUser(String username) => "hello, $username";
```

A simple script to test this service would be:

```Dart
import 'package:unittest/unittest.dart';

import 'package:bloodless/server.dart' as app;
import 'package:bloodless/mocks.dart';

import 'package:your_package_name/services.dart';

main() {

  //load the services in 'services' library
  setUp(() => app.setUp([#services]);
  
  //remove all loaded services
  tearDown(() => app.tearDown());
  
  test("hello service", () {
    //create a mock request
    var req = new MockRequest("/user/luiz");
    //dispatch the request
    return app.dispatch(req).then((resp) {
      //verify the response
      expect(resp.statusCode, equals(200));
      expect(resp.mockContent, equals("hello, luiz"));
    });
  })
  
}
```

**NOTE: To learn more about unit tests in Dart, take a look at [this article](https://www.dartlang.org/articles/dart-unit-tests/).**

## Deploying the app

The easiest way to build your app is using the [grinder](http://pub.dartlang.org/packages/grinder) library. Bloodless provides a simples task to properly copy the server's files to the build folder, which you can use in your build script. For example:

* Create a `build.dart` file inside the `bin` folder
```Dart
import 'package:grinder/grinder.dart';
import 'package:grinder/grinder_utils.dart';
import 'package:bloodless/tasks.dart';

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

**NOTE: You can improve your build script according to your needs.**

