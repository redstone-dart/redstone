library server_tests;

import 'dart:convert';

import 'package:unittest/unittest.dart';

import 'package:bloodless/server.dart' as app;
import 'package:bloodless/mocks.dart';
import 'package:logging/logging.dart';

import 'services/type_serialization.dart';
import 'services/arguments.dart';
import 'services/errors.dart';
import 'services/interceptors.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';

main() {
  
  //app.setupConsoleLog(Level.ALL);
  
  group("Response serialization:", () {
    
    setUp(() => app.setUp([#type_serialization]));
    
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
    
    tearDown(() => app.tearDown());
    
  });
  
  group("Route arguments:", () {
    
    setUp(() => app.setUp([#arguments]));
    
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
    
    test("request's content as JSON", () {
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
    
    test("request's content as FORM", () {
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
    
    tearDown(() => app.tearDown());
    
  });
  
  group("Error handling:", () {
    
    setUp(() => app.setUp([#errors]));
    
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
        print(resp.mockContent);
      });
    });
    
    tearDown(() => app.tearDown());
    
  });
  
  group("Chain:", () {
    
    setUp(() => app.setUp([#interceptors]));
    
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
       var req = new MockRequest("/basicauth");
       req.headers.set(HttpHeaders.AUTHORIZATION, "Basic xxx");
       return app.dispatch(req).then((resp) {
         expect(resp.headers[HttpHeaders.WWW_AUTHENTICATE][0], equals('Basic realm="Bloodless"'));   
         expect(resp.statusCode, equals(401));   
       });
     });
    
    test("basic auth", () {
       var req = new MockRequest("/basicauth");
       // username: 'Aladdin' password: 'open sesame'
       // Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
       req.headers.set(HttpHeaders.AUTHORIZATION, 'Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==');
       return app.dispatch(req).then((resp) {
         expect(resp.statusCode, equals(200));
         expect(resp.mockContent, equals("basic_auth"));
       });
     });
    
    tearDown(() => app.tearDown());
    
  });
}