---
layout: doc
menu_item: doc
title: Error Handlers
prev: Interceptors
next: Groups
---
The `@ErrorHandler` annotation is used to define an error handler:

```dart
@app.ErrorHandler(HttpStatus.NOT_FOUND)
handleNotFoundError() => app.redirect("/error/not_found.html");
```

Also, you can define an error handler for a specific URL pattern

```dart
@app.ErrorHandler(HttpStatus.NOT_FOUND, urlPattern: r'/public/.+')
handleNotFoundError() => app.redirect("/error/not_found.html");
```

If you define an error handler inside a group, then the handler will be restricted to the group path.

```dart
@app.Group('/user')
class User {

  @app.ErrorHandler(500)
  onInternalServerError() {
    if (app.chain.error is UserException) {
      ...
    } 
  }

  @app.Route('/find')
  find() {
    ...
  }
}
```

When an error happens, Redstone.dart will invoke the most specific handler for the request.

