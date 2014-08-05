---
layout: doc
menu_item: doc
title: Groups
prev: Error-handlers
next: Dependency-Injection
---
The `@Group` annotation is used to define a group of routes, interceptors and error handlers:

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

The prefix defined with the `@Group` annotation, will be prepended in every route and interceptor inside the group. If you need to directly bind to the group's path, you can use the `@DefaultRoute` annotation:

```dart
@Group("/user")
class UserService {
  
  @app.DefaultRoute()
  getUser() {
    ...
  }

  @app.DefaultRoute(methods: const[app.POST])
  postUser(@app.Body(app.JSON) Map user) {
    ...
  }

  @app.Route("/:id")
  getUserById(String id) {
   ...
  }
}

```

