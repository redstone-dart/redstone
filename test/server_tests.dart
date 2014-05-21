library server_tests;

import 'dart:convert';
import 'dart:io';

import 'package:unittest/unittest.dart';

import 'package:di/di.dart';
import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;
import 'package:redstone/mocks.dart';
import 'package:logging/logging.dart';

import 'services/routes.dart';
import 'services/type_serialization.dart';
import 'services/arguments.dart';
import 'services/errors.dart';
import 'services/interceptors.dart';
import 'services/dependency_injection.dart';
import 'services/install_lib.dart';
import 'services/plugins.dart';

main() {
  
  //app.setupConsoleLog(Level.ALL);
  
  group("Routes:", () {
    
    setUp(() => app.setUp([#routes]));
    tearDown(app.tearDown);
    
    test("path matching", () {
      var req = new MockRequest("/path/subpath");
      var req2 = new MockRequest("/path/anotherpath");
      var req3 = new MockRequest("/paths");
      
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("sub_route"));
      }).then((_) => app.dispatch(req2)).then((resp) {
        expect(resp.mockContent, equals("main_route"));
      }).then((_) => app.dispatch(req3)).then((resp) {
        expect(resp.statusCode, equals(404));
      });
    });
    
    test("group path matching", () {
      var req = new MockRequest("/group/path/subpath");
      var req2 = new MockRequest("/group/path/anotherpath");
      var req3 = new MockRequest("/group/path");
      var req4 = new MockRequest("/group/paths");
      
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("interceptor sub_route"));
      }).then((_) => app.dispatch(req2)).then((resp) {
        expect(resp.mockContent, equals("interceptor main_route"));
      }).then((_) => app.dispatch(req3)).then((resp) {
        expect(resp.mockContent, equals("interceptor main_route"));
      }).then((_) => app.dispatch(req4)).then((resp) {
        expect(resp.statusCode, equals(404));
      });
    });
    
  });
  
  group("Response serialization:", () {
    
    setUp(() => app.setUp([#type_serialization]));
    tearDown(app.tearDown);
    
    test("String -> text/plain", () {
      var req = new MockRequest("/types/string");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), contains("text/plain"));
        expect(resp.mockContent, equals("string"));
      });
    });
    
    test("Map -> application/json", () {
      var req = new MockRequest("/types/map");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), contains("application/json"));
        expect(JSON.decode(resp.mockContent), equals({"key1": "value1", "key2": "value2"}));
      });
    });
    
    test("List -> application/json", () {
      var req = new MockRequest("/types/list");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), contains("application/json"));
        expect(JSON.decode(resp.mockContent), equals(["value1", "value2", "value3"]));
      });
    });
    
    test("null -> empty response", () {
      var req = new MockRequest("/types/null");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), isNull);
        expect(resp.mockContent, isEmpty);
      });
    });
    
    test("Future -> (wait its completion)", () {
      var req = new MockRequest("/types/future");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), contains("application/json"));
        expect(JSON.decode(resp.mockContent), equals({"key1": "value1", "key2": "value2"}));
      });           
    });
    
    test("other types -> text/plain", () {
      var req = new MockRequest("/types/other");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), contains("text/plain"));
        expect(resp.mockContent, equals("other_type"));
      });
    });
    
    test("File -> (MimeType of the file)", () {
      var req = new MockRequest("/types/file");
      return app.dispatch(req).then((resp) {
        expect(resp.headers.value("content-type"), contains("application/json"));
        expect(JSON.decode(resp.mockContent), equals({"key": "value"}));
      });
    });
    
    test("Shelf Response", () {
      var req = new MockRequest("/types/shelf_response");
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("target_executed"));
      });
    });
    
  });
  
  group("Route arguments:", () {
    
    setUp(() => app.setUp([#arguments]));
    tearDown(app.tearDown);
    
    test("path parameters", () {
      var req = new MockRequest("/args/arg/1/1.2");
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg1": "arg", 
          "arg2": 1, 
          "arg3": 1.2, 
          "arg4": null, 
          "arg5": "arg5"
        }));
      });
    });
    
    test("path parameters with named arguments", () {
      var req = new MockRequest("/named_args/arg1/arg2");
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg1": "arg1", 
          "arg2": "arg2",  
          "arg3": null, 
          "arg4": "arg4"
        }));
      });
    });
    
    test("query parameters", () {
      var req = new MockRequest("/query_args", queryParams: {
        "arg1": "arg1", "arg2": "1", "arg3": "1.2"
      });
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg1": "arg1", 
          "arg2": 1, 
          "arg3": 1.2, 
          "arg4": null, 
          "arg5": "arg5",
          "arg6": null,
          "arg7": "arg7"
        }));
      });
    });
    
    test("query parameters with named arguments", () {
      var req = new MockRequest("/named_query_args", queryParams: {
        "arg1": "arg1", "arg2": "arg2"
      });
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg1": "arg1", 
          "arg2": "arg2", 
          "arg3": null, 
          "arg4": "arg4",
          "arg5": null,
          "arg6": "arg6"
        }));
      });
    });
    
    test("path and query parameters", () {
      var req = new MockRequest("/path_query_args/arg1", queryParams: {
        "arg": "arg2"
      });
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg": "arg1", 
          "qArg": "arg2"
        }));
      });
    });
    
    test("request content as JSON", () {
      var req = new MockRequest("/json/arg1", method: app.POST, bodyType: app.JSON, body: {
        "key": "value"
      });
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg": "arg1",
          "json": {"key": "value"}
        }));
      });
    });
    
    test("request content as FORM", () {
      var req = new MockRequest("/form/arg1", method: app.POST, bodyType: app.FORM, body: {
        "key": "value"
      });
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "arg": "arg1",
          "form": {"key": "value"}
        }));
      });
    });
    
    test("request attributes", () {
      var req = new MockRequest("/attr/arg1");
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("name_attr arg1 1"));
      });
    });
    
  });
  
  group("Error handling:", () {
    
    setUp(() => app.setUp([#errors]));
    tearDown(app.tearDown);
    
    test("wrong method", () {
      var req = new MockRequest("/wrong_method");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(405));
      });
    });
    
    test("wrong type", () {
      var req = new MockRequest("/wrong_type", method: app.POST, 
          bodyType: app.FORM, body: {"key": "value"});
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(400));
      });
    });
    
    test("wrong value", () {
      var req = new MockRequest("/wrong_value/not_int");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(400));
      });
    });
    
    test("route error", () {
      var req = new MockRequest("/route_error");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(500));
        expect(resp.mockContent, equals("server_error"));
      });
    });
 
    test("async route error", () {
      var req = new MockRequest("/async_route_error");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(500));
        expect(resp.mockContent, equals("server_error"));
      });
    });
    
    test("interceptor error", () {
      var req = new MockRequest("/interceptor_error");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(500));
        expect(resp.mockContent, equals("server_error"));
      });
    });
    
    test("async interceptor error", () {
      var req = new MockRequest("/async_interceptor_error");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(500));
        expect(resp.mockContent, equals("target_executed server_error"));
      });
    });
    
    test("resource not found", () {
      var req = new MockRequest("/not_found");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(404));
        expect(resp.mockContent, equals("not_found"));
      });
    });
    
    test("Ignore route response if abort() is called", () {
      var req = new MockRequest("/abort");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(500));
        expect(resp.mockContent, equals("server_error"));
      });
    });
    
    test("Ignore route response if redirect() is called", () {
      var req = new MockRequest("/redirect");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(302));
      });
    });
    
    test("Find error handler by path", () {
      var req = new MockRequest("/sub_handler");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(500));
        expect(resp.mockContent, equals("server_error sub_error_handler"));
      });
    });
  });
  
  group("Chain:", () {
    
    setUp(() => app.setUp([#interceptors]));
    tearDown(app.tearDown);
    
    test("interceptors", () {
      var req = new MockRequest("/target");
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("before_interceptor1|before_interceptor2|target_executed|after_interceptor2|after_interceptor1"));
      });
    });
    
    test("interrupt", () {
      var req = new MockRequest("/interrupt");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(401));
        expect(resp.mockContent, equals("chain_interrupted"));      
      });
    });
    
    test("redirect", () {
      var req = new MockRequest("/redirect");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(302));   
      });
    });
    
    test("abort", () {
      var req = new MockRequest("/abort");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(401));   
      });
    });
    
    test("without basic auth", () {
       var req = new MockRequest("/basicauth");
       return app.dispatch(req).then((resp) {
         expect(resp.statusCode, equals(401));   
       });
     });
    
    test("wrong basic auth", () {
       var headers = {HttpHeaders.AUTHORIZATION: "Basic xxx"};
       var req = new MockRequest("/basicauth", headers: headers);
       return app.dispatch(req).then((resp) {
         expect(resp.headers[HttpHeaders.WWW_AUTHENTICATE][0], equals('Basic realm="Redstone"'));   
         expect(resp.statusCode, equals(401));   
       });
     });
    
    test("basic auth", () {
       // username: 'Aladdin' password: 'open sesame'
       // Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
       var headers = {HttpHeaders.AUTHORIZATION: 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ=='};
       var req = new MockRequest("/basicauth", headers: headers);
       return app.dispatch(req).then((resp) {
         expect(resp.statusCode, equals(200));
         expect(resp.mockContent, equals("basic_auth"));
       });
     });
    
    test("basic auth parse", () {
       var req = new MockRequest("/basicauth_data", 
             basicAuth: new app.Credentials("Aladdin", "open sesame"));
       return app.dispatch(req).then((resp) {
         expect(resp.statusCode, equals(200));
         expect(resp.mockContent, equals("basic_auth"));
       });
     });
    
  });
  
  group("dependency injection:", () {
    
    setUp(() { 
      app.addModule(new Module()
         ..bind(A)
         ..bind(B)
         ..bind(C));
      app.setUp([#dependency_injection]);
    });
    tearDown(() => app.tearDown());
    
    test("Routes and interceptors", () {
      var req = new MockRequest("/di");
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("value_a value_b value_a value_b"));
      });
    });
    
    test("Groups", () {
      var req = new MockRequest("/group/di");
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("value_a value_b"));
      });
    });
    
    test("Error handlers", () {
      var req = new MockRequest("/invalid_path");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(404));
        expect(resp.mockContent, equals("value_a value_b"));
      });
    });
  });
  
  group("install library:", () {
    
    setUp(() => app.setUp([#install_lib]));
    tearDown(app.tearDown);
    
    test("URL prefix", () {
      var req = new MockRequest("/prefix/route");
      var req2 = new MockRequest("/prefix/group/route");
      var req3 = new MockRequest("/prefix/error");
      
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("interceptor_executed target_executed"));
      }).then((_) => app.dispatch(req2)).then((resp) {
        expect(resp.mockContent, equals("interceptor_executed target_executed"));
      }).then((_) => app.dispatch(req3)).then((resp) {
        expect(resp.mockContent, equals("error_handler_executed"));
      });
    });
    
    test("Chain", () {
      var req = new MockRequest("/chain/route");
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("root interceptor_1 interceptor_2 interceptor_3 interceptor_4 target "));
      });
    });
    
    test("@Ignore", () {
      var req = new MockRequest("/ignore");
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(404));
      });
    });
  });
  
  group("Plugins:", () {
    
    setUp(() { 
      app.addPlugin(FromJsonPlugin);
      app.addPlugin(ToJsonPlugin);
      app.addPlugin(TestPlugin);
      app.setUp([#plugins]);
    });
    tearDown(app.tearDown);
    
    test("Parameter provider", () {
      
      var req = new MockRequest("/user", method: app.POST, bodyType: app.JSON, body: {
        "name": "name",
        "username": "username"
      });
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("name: name username: username"));
      });
      
    });
    
    test("Parameter provider - exception", () {
      var req = new MockRequest("/user", method: app.POST, bodyType: app.FORM, body: {
        "name": "name",
        "username": "username"
      });
      return app.dispatch(req).then((resp) {
        expect(resp.statusCode, equals(400));
      });
    });
    
    test("Response processor", () {
      var req = new MockRequest("/user/find");
      
      return app.dispatch(req).then((resp) {
        expect(JSON.decode(resp.mockContent), equals({
          "name": "name",
          "username": "username"
        }));
      }); 
    });
    
    test("Routes", () {
      var req = new MockRequest("/route/value");
      var req2 = new MockRequest("/error");
      
      return app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("interceptor value"));
      }).then((_) => app.dispatch(req2)).then((resp) {
        expect(resp.mockContent, equals("error_handler"));
      });
    });
  });
  
  group("Shelf:", () {
    
    tearDown(app.tearDown);
    
    test("Middlewares", () {
      
      app.addShelfMiddleware(shelf.createMiddleware(responseHandler: (shelf.Response resp) {
        return resp.readAsString().then((value) =>
            new shelf.Response.ok("middleware_1 $value"));
      }));
      app.addShelfMiddleware(shelf.createMiddleware(responseHandler: (shelf.Response resp) {
        return resp.readAsString().then((value) =>
            new shelf.Response.ok("middleware_2 $value"));
      }));
      app.setUp([#routes]);
      
      MockRequest req = new MockRequest("/path");
      app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("middleware_1 middleware_2 main_route"));
      });
      
    });
    
    test("Handler", () {
      app.setShelfHandler((shelf.Request req) {
        return new shelf.Response.ok("handler_executed");
      });
      app.setUp([#routes]);
      MockRequest req = new MockRequest("/invalid_path");
      app.dispatch(req).then((resp) {
        expect(resp.mockContent, equals("handler_executed"));
        expect(resp.statusCode, equals(200));
      });
    });
  });
  
}