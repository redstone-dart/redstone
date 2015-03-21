library plugins;

import 'dart:mirrors';

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

//plugin - parameter provider

class FromJson {
  const FromJson();
}

FromJsonPlugin(Manager manager) {
  manager.addParameterProvider(FromJson,
      (metadata, type, handlerName, paramName, req, injector) {
    if (req.bodyType != JSON) {
      throw new ErrorResponse(400, "content-type must be 'application/json'");
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
    return {"name": name, "username": username};
  }

  toString() => "name: $name username: $username";
}

@Route("/user", methods: const [POST])
printUser(@FromJson() User user) => user.toString();

//plugin - response processor

class ToJson {
  const ToJson();
}

ToJsonPlugin(Manager manager) {
  manager.addResponseProcessor(ToJson,
      (metadata, handlerName, value, injector) {
    if (value == null) {
      return value;
    }
    return value.toJson();
  });
}

//test plugin

@Route("/user/find")
@ToJson()
returnUser() {
  var user = new User();
  user.name = "name";
  user.username = "username";
  return user;
}

//plugin - add routes, interceptors and error handlers

TestPlugin(Manager manager) {
  Route route = new Route("/route/:arg");
  Interceptor interceptor = new Interceptor("/route/.+");

  Route routeError = new Route("/error");
  ErrorHandler errorHandler = new ErrorHandler(500);

  manager.addRoute(route, "testRoute", (injector, request) {
    return request.urlParameters["arg"];
  });

  manager.addInterceptor(interceptor, "testInterceptor",
      (injector, request) async {
    await chain.next();
    return response
        .readAsString()
        .then((resp) => new shelf.Response.ok("interceptor $resp"));
  });

  manager.addRoute(routeError, "testError", (injector, request) {
    throw "error";
  });

  manager.addErrorHandler(errorHandler, "testErrorHandler",
      (injector, request) {
    return new shelf.Response.internalServerError(body: "error_handler");
  });
}

//plugin - add route wrappers

class Wrap {
  const Wrap();
}

WrapperPlugin(Manager manager) {
  manager.addRouteWrapper(Wrap, (wrap, injector, request, route) async {
    var resp = await route(injector, request);
    return "response: $resp";
  }, includeGroups: true);
}

@Route("/test_wrapper")
@Wrap()
testWrapper() => "target executed";

@Group("/test_group_wrapper")
@Wrap()
class TestGroupWrapper {
  @Route("/test_wrapper")
  testWrapper() => "target executed";
}

//test scanning

class TestAnnotation {
  const TestAnnotation();
}

@TestAnnotation()
void annotatedFunction() {}

@TestAnnotation()
class AnnotatedClass {
  @TestAnnotation()
  void annotatedMethod() {}
}

//Helper class to handle mirror objects
class CapturedType {
  Symbol typeName;
  Object metadata;

  CapturedType(AnnotatedType annotatedType) {
    typeName = annotatedType.mirror.simpleName;
    metadata = annotatedType.metadata;
  }

  CapturedType.fromValues(this.typeName, this.metadata);

  operator ==(other) {
    return other is CapturedType &&
        other.typeName == typeName &&
        other.metadata == metadata;
  }

  toString() => "@${metadata} $typeName";
}
