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
  // ...
}
```

You can also bind the request body

```dart
@app.Route("/user/add", methods: const [app.POST])
addUser(@app.Body(app.JSON) Map user) {
  // ...
}
```

It's also possible to access the current request object

```dart
@app.Route("/service", methods: const [app.GET, app.POST])
service() {
  if (app.request.method == app.GET) {
    // ...
  } else if (app.request.method == app.POST) {
    if (app.request.bodyType == app.JSON) {
      var json = app.request.body;
      // ...
    } else {
      // ...
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
    return app.chain.next();
  } else {
    return app.chain.abort(HttpStatus.UNAUTHORIZED);
    //or app.chain.redirect("/login.html");
  }
}
```

```dart
@app.Interceptor(r'/services/.+')
dbConnInterceptor() async {
  var conn = new DbConn();
  
  app.request.attributes["dbConn"] = conn;
  var response = await app.chain.next();
  
  await conn.close()
  
  return response;
}

@app.Route('/services/find')
find(@app.Attr() dbConn) {
  // ...
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
    // ...
  }

  @app.Route("/add", methods: const [app.POST])
  addUser(@app.Body(app.JSON) Map json) {
    // ...
  }
}
```

## Dependency Injection

Register one or more modules before calling `app.start()`

{% include code.func code="di.dart" %}

Routes, interceptors, error handlers and groups can require dependencies

```dart
@app.Route('/service')
service(@app.Inject() ClassA objA) {
 // ...
}
```

```dart
@app.Interceptor(r'/services/.+')
interceptor(ClassA objA, ClassB objB) {
  // ...
}
```

```dart
@app.ErrorHandler(404)
notFound(ClassB objB) {
  // ...
}
```

```dart
@app.Group('/group')
class Group {
  ClassA objA;
  
  Group(ClassA this.objA);
  
  @app.Route('/service')
  service() {
    // ...
  }
}
```

### Unit tests

You can easily create mock requests to test your server

{% include code.func code="services.dart" %}

{% include code.func code="services_test.dart" %}
