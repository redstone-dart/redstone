---
layout: doc
menu_item: doc
title: Routes
prev: Feature-tour
next: Interceptors
---
The `@Route` annotation is used to bind a function or method to an URL:

```dart
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

```dart
@app.Route("/")
helloWorld() => new Future(() => "Hello, World!");
```

If you need to respond the request with a status code different than 200, you can return or throw an `ErrorResponse`;

```dart
@app.Route("/user/:id")
getUser(int id) {
  if (id <= 0) {
    throw new app.ErrorResponse(400, {"error": "invalid id"});
  }
  ...
}
```
You can also build a response using [Shelf](http://pub.dartlang.org/packages/shelf).

```dart
import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/")
helloWorld() => new shelf.Response.ok("Hello, World!");
```
For other types, Redstone.dart will convert the value to a String, and send it as *text/plain*.

Also, it's possible to override the content type of the response:

```dart
@app.Route("/", responseType: "text/xml")
getXml() => "<root><node>text</node></root>";
```

## Parameters

### Path segments

It's possible to bind path segments with arguments:

```dart
@app.Route("/user/:username")
helloUser(String username) => "hello $username";
```

The argument doesn't need to be a String. If it's an int, for example, the framework will try to convert the value for you (if the conversion fails, a 400 status code is sent to the client).

```dart
@app.Route("/user/:username/:addressId")
getAddress(String username, int addressId) {
  ...
};
```

The supported types are: int, double and bool

### Query parameters

Use the `@QueryParam` annotation to access a query parameter

```dart
@app.Route("/user")
getUser(@app.QueryParam("id") int userId) {
  ...
};
```

Like path parameters, the argument doesn't need to be a String. 

### Request body

You can access the request body as a form, json or text

```dart
@app.Route("/adduser", methods: const [app.POST])
addUser(@app.Body(app.JSON) Map json) {
  ...
};
```

```dart
@app.Route("/adduser", methods: const [app.POST])
addUser(@app.Body(app.FORM) Map form) {
  ...
};
```

For json and form, you can request the body as a `QueryMap`, which allows the use of the dot notation

```dart
@app.Route("/adduser", methods: const [app.POST])
addUser(@app.Body(app.JSON) QueryMap json) {
  var name = json.name;
  ...
};
```

## HTTP Methods

By default, a route only responds to GET requests. You can change that with the `methods` arguments:

```dart
@app.Route("/user/:username", methods: const [app.GET, app.POST])
helloUser(String username) => "hello $username";
```

It's also possible to define multiple routes to the same path and different HTTP methods:

```dart
@app.Route("/user", methods: const [app.GET])
getUser() {
 ...
};

@app.Route("/user", methods: const [app.POST])
postUser(@app.Body(app.JSON) Map user) {
 ...
};
```

## Multipart requests (file uploads)

By default, Redstone.dart will refuse any multipart request. If your method needs to receive a multipart request, you can set `Route.allowMultipartRequest = true`. Example:

```dart
@app.Route("/adduser", methods: const [app.POST], allowMultipartRequest: true)
addUser(@app.Body(app.FORM) Map form) {
  var file = form["file"];
  print(file.filename);
  print(file.contentType);
  print(file.content);
  ...
};
```

## Matching sub paths

If you set `Route.matchSubPaths = true`, then the route will matches requests which path starts with the URL pattern. Example:

```dart
@app.Route('/path', matchSubPaths: true)
service() {
 ...
}

@app.Route('/path/subpath')
serviceB() {
 ...
}
```

If a request for `/path/subpath` is received, then `serviceB` is executed, but if a request for `/path/another_path` is received, `service` is executed.

Also, you can assign the requested sub path to a parameter, adding a trailing `*` character to the url template. Example:

```dart
@app.Route('/service/:path*', matchSubPaths: true)
service(String path) {
 ...
}
```

## The request object

You can use the global `request` object to access the request's information and content:

```dart
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

Each request is tied to its own [Zone](https://www.dartlang.org/articles/zones/), so it's also safe to access the request object in async operations.

## The response object

Sometimes, you need to directly build a HTTP response, or inspect and modify a response created by another handler (a route, interceptor or error handler). For those cases, you can rely on the `response` object, which points to the last response created for the current request. Example:

```dart
import 'package:redstone/server.dart' as app;

@app.Interceptor(r'/.*')
interceptor() {
  app.chain.next(() {
    app.response = app.response.change(headers: {
      "Access-Control-Allow-Origin": "*"
    });
  });
}
```

Also, if you are building a response inside a **chain callback**, **route** or **error handler**, you can just return it:

```dart
import 'package:redstone/server.dart' as app;

@app.Interceptor(r'/.*')
interceptor() {
  app.chain.next(() {
    return app.response.change(headers: {
      "Access-Control-Allow-Origin": "*"
    });
  });
}
```