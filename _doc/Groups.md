---
layout: doc
menu_item: doc
title: Groups
prev: Error-handlers
next: Dependency-Injection
---
The `@app.Group` annotation is used to define a group of routes, interceptors and error handlers:

```dart
@app.Group("/user")
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

The prefix defined with the `@app.Group` annotation, will be prepended in every route and interceptor inside the group. If you need to directly bind to the group's path, you can use the `@DefaultRoute` annotation:

```dart
@app.Group("/user")
class UserService {
  @app.DefaultRoute()
  getUser() {
    // ...
  }

  @app.DefaultRoute(methods: const[app.POST])
  postUser(@app.Body(app.JSON) Map user) {
    // ...
  }

  @app.Route("/:id")
  getUserById(String id) {
   // ...
  }
}

```

## Extending the group annotation

If you wish to create your own custom groups, you can extend the default Group annotation.

```dart
class ApiGroup extends app.Group {
  const ApiGroup(String urlPrefix) : super("/api" + urlPrefix);
}

@ApiGroup('/todo')
class ApiTodoService {
  @app.DefaultRoute()
  getTodo() {
    // ...
  }
}
```
