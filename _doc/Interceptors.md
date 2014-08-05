---
layout: doc
menu_item: doc
title: Interceptors
prev: Routes
next: Error-handlers
---
The `@Interceptor` annotation is used to define an interceptor:

```dart
@app.Interceptor(r'/.*')
handleResponseHeader() {
  if (app.request.method == "OPTIONS") {
    //overwrite the current response and interrupt the chain.
    app.response = new shelf.Response.ok(null, headers: _createCorsHeader());
    app.chain.interrupt();
  } else {
    //process the chain and wrap the response
    app.chain.next(() => app.response.change(headers: _createCorsHeader()));
  }
}

_createCorsHeader() => {"Access-Control-Allow-Origin": "*"};
```

## The chain object

Each request is actually a chain, composed by 0 or more interceptors, and a route. An interceptor is a structure that allows you to apply a common behavior to a group of targets. For example, you can use an interceptor to apply a security constraint, or to manage a resource:

```dart
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

```dart
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

When a request is received, the framework will execute all interceptors that matches the URL, and then will look for a valid route. If a route is found, it will be executed.

Each interceptor must call the `chain.next()` or `chain.interrupt()` methods, otherwise, the request will be stuck. The `chain.next()` method can receive a callback, that is executed when the target completes. All callbacks are executed in the reverse order they are created. If a callback returns a `Future`, then the next callback will execute only when the future completes.

For example, consider this script:

```dart
import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/")
helloWorld() => "target\n";

@app.Interceptor(r'/.*', chainIdx: 0)
interceptor1() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
        new shelf.Response.ok(
          "interceptor 1 - before target\n$resp|interceptor 1 - after target\n"));
  });
}

@app.Interceptor(r'/.*', chainIdx: 1)
interceptor2() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
        new shelf.Response.ok(
          "interceptor 2 - before target\n$resp|interceptor 2 - after target\n"));
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

It's also possible to verify if the target threw an error (if there is an error handler registered, it will be invoked before the callback):

```dart
@app.Interceptor(r'/.*')
interceptor() {
  app.chain.next(() {
    if (app.chain.error != null) {
      ...
    }
  });
}
```

## The request body

By default, Redstone.dart won't parse the request body until all interceptors are called. If your interceptor need to inspect the request body, you must set `parseRequestBody = true`. Example:

```dart
@app.Interceptor(r'/service/.+', parseRequestBody: true)
verifyRequest() {
  //if parseRequestBody is not setted, request.body is null
  print(app.request.body);
  app.chain.next();
}

```

## Controlling execution order

You can control what order interceptors get executed by specifying chainIdx

```dart

@app.Interceptor("/.+", chainIdx: 0)
interceptor() {
  print("interceptor 2");
  app.chain.next();
}

@app.Interceptor("/.+", chainIdx: 1)
interceptor2() {
  print("interceptor 3");
  app.chain.next();
}
```