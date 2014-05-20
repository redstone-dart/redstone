library plugins;

import 'dart:mirrors';

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

//plugin - parameter provider

class FromJson {
  
  const FromJson();
  
}

FromJsonPlugin(app.Manager manager) {
  
  manager.addParameterProvider(FromJson, (metadata, type, handlerName, paramName, req, injector) {
    if (req.bodyType != app.JSON) {
      throw new app.RequestException("FromJson plugin - $handlerName", "content-type must be 'application/json'");
    }
    
    ClassMirror clazz = reflectClass(type);
    InstanceMirror obj = clazz.newInstance(const Symbol(""), const []);
    obj.invoke(#fromJson, [req.body]);
    return obj.reflectee;
  });
  
}

//test plugin

class User {
  String name;
  String username;
  
  fromJson(Map json) {
    name = json["name"];
    username = json["username"];
  }
  
  toJson() {
    return {
      "name": name,
      "username": username
    };
  }
  
  toString() => "name: $name username: $username";
}

@app.Route("/user", methods: const[app.POST])
printUser(@FromJson() User user) => user.toString();

//plugin - response processor

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

//test plugin

@app.Route("/user/find")
@ToJson()
returnUser() {
  var user = new User();
  user.name = "name";
  user.username = "username";
  return user;
}

//plugin - add routes, interceptors and error handlers

TestPlugin(app.Manager manager) {
  
  app.Route route = new app.Route.conf("/route/:arg"); 
  app.Interceptor interceptor = new app.Interceptor.conf("/route/.+");
  
  app.Route routeError = new app.Route.conf("/error");
  app.ErrorHandler errorHandler = new app.ErrorHandler.conf(500);
  
  manager.addRoute(route, "testRoute", (pathSegments, injector, request) {
    return pathSegments["arg"];
  });
  
  manager.addInterceptor(interceptor, "testInterceptor", (injector) {
    app.chain.next(() {
      return app.response.readAsString().then((resp) {
        app.response = new shelf.Response.ok("interceptor $resp");
      });
    });
  });
  
  manager.addRoute(routeError, "testError", (pathSegments, injector, request) {
    throw "error";
  });
  
  manager.addErrorHandler(errorHandler, "testErrorHandler", (injector) {
    app.response = new shelf.Response.internalServerError(body: "error_handler");
  });
  
}