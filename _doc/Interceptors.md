---
layout: doc
menu_item: doc
title: Interceptors
prev: Routes
next: Error-handlers
---
The `@Interceptor` annotation is used to define an interceptor:

```dart
import 'package:redstone/redstone.dart';
import "package:shelf/shelf.dart" as shelf;

@Interceptor(r'/.*')
handleCORS() async {
  if (request.method != "OPTIONS") {
    await chain.next();
  }
  return response.change(headers: {"Access-Control-Allow-Origin": "*"});
}
```

## The chain object

Each request is actually a chain, composed by 0 or more interceptors, and a route. 
An interceptor is a structure that allows you to apply a common behavior to a group of targets. 
For example, you can use an interceptor to apply a security constraint, or to manage a resource.
Here's an example of a CORS interceptor:

```dart
import 'package:redstone/redstone.dart' as app;

@app.Interceptor(r'/.*')
handleCORS() async {
  if (app.request.method != "OPTIONS") {
    await app.chain.next();
  }
  
  return app.response.change(headers: {"Access-Control-Allow-Origin": "*"});
}
```

Here's another interceptor example. This one injects a new database connection object during the request, and closes it after
the chain finishes.


```dart
import 'package:redstone/redstone.dart' as app;

@app.Interceptor(r'/services/.+')
dbConnInterceptor() async {
  var conn = new DbConn();
  app.request.attributes["dbConn"] = conn;
  
  var response = await app.chain.next();
  await conn.close();
  
  return response;
}

@app.Route('/services/find')
find(@app.Attr() dbConn) {
  // ...
}
```

When a request is received, the framework will execute all interceptors that matches the URL, 
and then will look for a valid route. If a route is found, it will be executed.

Each interceptor must call the `chain.next()` or `chain.abort()` methods, otherwise, the request will be stuck. 
The `chain.next()` and `chain.abort()` functions now return a `Future<shelf.Response>`. It's necessary to wait for the 
completion of the returned future when calling one of these functions, although, it's now possible to use them with 
`async`/`await` expressions. 

For example, consider this script:

```dart
import 'package:redstone/redstone.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/")
helloWorld() => "target\n";

@app.Interceptor(r'/.*', chainIdx: 0)
interceptor1() async {
  var response = await app.chain.next();

  String responseText = await response.readAsString();
  return new shelf.Response.ok(
      "interceptor 1 - before target\n${responseText}interceptor 1 - after target\n");
}

@app.Interceptor(r'/.*', chainIdx: 1)
interceptor2() async {
  var response = await app.chain.next();

  String responseText = await response.readAsString();
  return new shelf.Response.ok(
      "interceptor 2 - before target\n${responseText}interceptor 2 - after target\n");
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
interceptor() async {
  await app.chain.next();
  if (app.chain.error != null) {
    // Handle error
  }
}
```

The `chain.redirect()` creates a new response with an 302 status code.

## The request body

By default, Redstone.dart won't parse the request body until all interceptors are called. If your interceptor needs to 
inspect the request body, you must set `parseRequestBody = true`. Example:

```dart
@app.Interceptor(r'/service/.+', parseRequestBody: true)
verifyRequest() async {
  //if parseRequestBody is not setted, request.body is null
  print(app.request.body);
  var response = await app.chain.next();
  
  return response;
}

```

## Controlling execution order

You can control what order interceptors get executed by specifying chainIdx

```dart
@app.Interceptor("/.+", chainIdx: 0)
interceptor() {
  print("interceptor 2");
  return app.chain.next();
}

@app.Interceptor("/.+", chainIdx: 1)
interceptor2() {
  print("interceptor 3");
  return app.chain.next();
}
```
