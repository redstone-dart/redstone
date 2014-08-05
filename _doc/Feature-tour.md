---
layout: doc
menu_item: doc
title: Feature Tour
prev: Installation
next: Routes
---
##Routes

To bind a function with an URL, just use the `@Route` annotation

```dart
@app.Route("/")
helloWorld() => "Hello, World!";
```

Redstone.dart will serialize the returned value for you. So, if your function returns a `List` or a `Map`, the client receives a JSON object:

```dart
@app.Route("/user/find/:id")
getUser(String id) => {"name": "User", "login": "user"};
```

If your function depends on async operations, you can also return a `Future`

```dart
@app.Route("/service")
service() => doSomeAsyncOperation().then((_) => {"success": true});
```

You can easily bind path segments and query parameters

```dart
@app.Route("/user/find/:type")
findUsers(String type, @app.QueryParam() String name) {
  ...
}
```

You can also bind the request body

```dart
@app.Route("/user/add", methods: const [app.POST])
addUser(@app.Body(app.JSON) Map user) {
  ...
}
```

It's also possible to access the current request object

```dart
@app.Route("/service", methods: const [app.GET, app.POST])
service() {
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

##Interceptors

Interceptors are useful when you need to apply a common behavior to a group of targets (functions or static content). For example, you can create an interceptor to apply a security constraint or to manage a resource

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

##Error Handlers

Use the `@ErrorHandler` annotation to register error handlers.

```dart
@app.ErrorHandler(404)
handleNotFoundError() => app.redirect("/error/not_found.html");
```

```dart
@app.ErrorHandler(500)
handleServerError() {
  print(app.chain.error);
  return new shelf.Response.internalServerError(body: "Server Error.");
}
```

##Groups

You can use classes to group routes, interceptors and error handlers

```dart
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

## Dependency Injection

Register one or more modules before calling `app.start()`

```dart
import 'package:redstone/server.dart' as app;
import 'package:di/di.dart';

main() {

  app.addModule(new Module()
       ..bind(ClassA)
       ..bind(ClassB));
  
  app.setupConsoleLog();
  app.start();

}

```

Routes, interceptors, error handlers and groups can require dependencies

```dart
@app.Route('/service')
service(@app.Inject() ClassA objA) {
 ...
}
```

```dart
@app.Interceptor(r'/services/.+')
interceptor(ClassA objA, ClassB objB) {
  ...
}
```

```dart
@app.ErrorHandler(404)
notFound(ClassB objB) {
  ...
}
```

```dart
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

### Unit tests

You can easily create mock requests to test your server

```dart
library services;

import 'package:redstone/server.dart' as app;

@app.Route("/user/:username")
helloUser(String username) => "hello, $username";
```

```dart
import 'package:unittest/unittest.dart';

import 'package:redstone/server.dart' as app;
import 'package:redstone/mocks.dart';

import 'package:your_package_name/services.dart';

main() {

  //load handlers in 'services' library
  setUp(() => app.setUp([#services]));
  
  //remove all loaded handlers
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