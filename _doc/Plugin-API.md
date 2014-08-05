---
layout: doc
menu_item: doc
title: Plugin API
prev: Importing-libraries
next: Shelf-Middlewares
---
Redstone plugins can dynamically create new routes, interceptors, error handlers, parameter providers and response processors.

**Note: See [redstone_mapper](https://github.com/luizmineo/redstone_mapper) for a more complete serialization plugin**

For example, if your app often needs to convert from json data to Dart objects, like this:

```dart
@app.Route("/user", methods: const[app.POST])
printUser(@app.Body() Map json) {
  User user = new User();
  user.fromJson(json);
  ...
}
```

You can build a plugin to do this job for you. Example:

```dart
class FromJson {
  
  const FromJson();
  
}

FromJsonPlugin(app.Manager manager) {
  
  manager.addParameterProvider(FromJson, (metadata, type, handlerName, paramName, req, injector) {
    if (req.bodyType != app.JSON) {
      throw new app.RequestException(
          "FromJson plugin - $handlerName", "content-type must be 'application/json'");
    }
    
    ClassMirror clazz = reflectClass(type);
    InstanceMirror obj = clazz.newInstance(const Symbol(""), const []);
    obj.invoke(#fromJson, [req.body]);
    return obj.reflectee;
  });
  
}
```
Now, if you install `FromJsonPlugin`, you can use the `@FromJson` annotation:

```dart
@app.Route("/user", methods: const[app.POST])
printUser(@FromJson() User user) {
  ...
}

main() {
  app.addPlugin(FromJsonPlugin);
  app.setupConsoleLog();
  app.start();
}
```

Besides, you can also build a plugin to convert from dart objects to json data:

```dart
class ToJson {
  
  const ToJson();
  
}

ToJsonPlugin(app.Manager manager) {
  manager.addResponseProcessor(ToJson, (metadata, handlerName, value, injector) {
    if (value == null) {
      return value;
    }
    return value.toJson();
  });
}
```

```dart
@app.Route("/user/find")
@ToJson()
findUser() {
  return new Future(() {
    ...
    return user;
  });
}

main() {
  app.addPlugin(ToJsonPlugin);
  app.setupConsoleLog();
  app.start();
}
```