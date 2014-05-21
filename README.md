Redstone.dart
=========

This is a beta version of Redstone.dart. If you want to try it out, you can update your pubspec.yaml to: 

```
name: my_app
 dependencies:
   redstone:
     git:
       url: git@github.com:luizmineo/redstone.dart.git
       ref: v0.5
```

##What's new?

Redstone.dart is now compatible with [Shelf](http://pub.dartlang.org/packages/shelf). That means you can use any Shelf Middleware or Handler in your app.

Example:

```Dart

main() {
  //Middlewares registered with addShelfMiddleware() will be invoked before
  //any interceptor or route.
  app.addShelfMiddleware(...);
  app.addShelfMiddleware(...);
  
  //The handler registered with setShelfHandler() will be invoked when all
  //interceptors are completed, and there is no route for the requested URL.
  app.setShelfHandler(...);

  app.setupConsoleLog();
  app.start();

}

```

##Breaking Changes

* Redstone.dart will no longer serve static files. If you need to serve static files, you can use a Shelf Handler. 

Example (using [shelf_static](http://pub.dartlang.org/packages/shelf_static)):

```Dart
import 'package:redstone/server.dart' as app;
import 'package:shelf_static/shelf_static.dart';

main() {
  app.setShelfHandler(createStaticHandler("../web", 
                                          defaultDocument: "index.html", 
                                          serveFilesOutsidePath: true));
  app.setupConsoleLog();
  app.start();
}

```

* Redstone.dart will no longer provide directly access to HttpRequest and HttpResponse objects. For example, if you have a route, interceptor or error handler that writes to HttpResponse, it must be updated to create a Shelf Response:

```Dart
import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Interceptor(r'/.*')
handleResponseHeader() {
  if (app.request.method == "OPTIONS") {
    //overwrite the current response and interrupt the chain.
    app.response = new shelf.Response.ok(null, headers: _createCorsHeader());
    app.chain.interrupt();
  } else {
    //process the chain and wrap the response
    app.chain.next(() =>
      new shelf.Response(app.response.statusCode, 
                         body: app.response.read(),
                         headers: new Map.from(app.response.headers)..addAll(_createCorsHeader())));
  }
}

_createCorsHeader() => {"Access-Control-Allow-Origin": "*"};
```
Also, routes and error handlers can now return a `Response` or `Future<Response>`

