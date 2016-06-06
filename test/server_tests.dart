library server_tests;

import 'dart:convert' as conv;
import 'dart:async';
import 'dart:mirrors';

import 'package:test/test.dart';

import 'package:di/di.dart';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

// These appear to be unused but are dynamically loaded and must be present.
import 'services/routes.dart' as yo;
import 'services/type_serialization.dart';
import 'services/arguments.dart';
import 'services/errors.dart';
import 'services/interceptors.dart';
import 'services/dependency_injection.dart';
import 'services/install_lib.dart';
import 'services/plugins.dart';
import 'services/inspect.dart';

void main() {
  showErrorPage = false;
  //setupConsoleLog(Level.ALL);

  group("Routes:", () {
    setUp(() => redstoneSetUp([#routes]));
    tearDown(redstoneTearDown);

    test("path matching", () async {
      var req = new MockRequest("/path/subpath");
      var req2 = new MockRequest("/path/anotherpath");
      var req3 = new MockRequest("/paths");
      var req4 = new MockRequest("/path2/sub/path");
      var req5 = new MockRequest("/change_status_code");

      var resp = await dispatch(req);
      expect(resp.mockContent, equals("sub_route"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("main_route"));
      resp = await dispatch(req3);
      expect(resp.statusCode, equals(404));
      resp = await dispatch(req4);
      expect(resp.mockContent, equals("sub/path"));
      resp = await dispatch(req5);
      expect(resp.statusCode, equals(201));
      expect(resp.mockContent, equals("response"));
    });

    test("group path matching", () async {
      var req = new MockRequest("/group/path/subpath");
      var req2 = new MockRequest("/group/path/anotherpath");
      var req3 = new MockRequest("/group/paths");
      var req4 = new MockRequest("/group");
      var req5 = new MockRequest("/group.json");
      var req6 = new MockRequest("/group", method: POST);
      var req7 = new MockRequest("/group/change_status_code");

      var resp = await dispatch(req);
      expect(resp.mockContent, equals("interceptor sub_route"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("interceptor main_route"));
      resp = await dispatch(req3);
      expect(resp.statusCode, equals(404));
      resp = await dispatch(req4);
      expect(resp.mockContent, equals("default_route"));
      resp = await dispatch(req5);
      expect(resp.mockContent, equals("default_route_json"));
      resp = await dispatch(req6);
      expect(resp.mockContent, equals("default_route_post"));
      resp = await dispatch(req7);
      expect(resp.statusCode, equals(201));
      expect(resp.mockContent, equals("response"));
    });

    test("compound group path matching", () async {
      var req = new MockRequest("/mixed/path/subpath");
      var req2 = new MockRequest("/mixed/path/anotherpath");
      var req3 = new MockRequest("/mixed/paths");
      var req4 = new MockRequest("/mixed");
      var req5 = new MockRequest("/mixed.json");
      var req6 = new MockRequest("/mixed", method: POST);
      var req7 = new MockRequest("/mixed/change_status_code");
      var req8 = new MockRequest("/mixed/info");
      var req9 = new MockRequest("/mixed/version");

      var resp = await dispatch(req);
      expect(resp.mockContent, equals("interceptor sub_route"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("interceptor main_route"));
      resp = await dispatch(req3);
      expect(resp.statusCode, equals(404));
      resp = await dispatch(req4);
      expect(resp.mockContent, equals("default_route"));
      resp = await dispatch(req5);
      expect(resp.mockContent, equals("default_route_json"));
      resp = await dispatch(req6);
      expect(resp.mockContent, equals("default_route_post"));
      resp = await dispatch(req7);
      expect(resp.statusCode, equals(202));
      expect(resp.mockContent, equals("mixed response"));
      resp = await dispatch(req8);
      expect(resp.mockContent, equals("info"));
      resp = await dispatch(req9);
      expect(resp.mockContent, equals("version"));
    });

    test("multiple handlers", () async {
      var req = new MockRequest("/handler_by_method");
      var req2 = new MockRequest("/handler_by_method", method: POST);

      var resp = await dispatch(req);
      expect(resp.mockContent, equals("get_handler"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("post_handler"));
    });
  });

  group("Response serialization:", () {
    setUp(() => redstoneSetUp([#type_serialization]));
    tearDown(redstoneTearDown);

    test("String -> text/plain", () async {
      var req = new MockRequest("/types/string");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), contains("text/plain"));
      expect(resp.mockContent, equals("string"));
    });

    test("Map -> application/json", () async {
      var req = new MockRequest("/types/map");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), contains("application/json"));
      expect(conv.JSON.decode(resp.mockContent),
          equals({"key1": "value1", "key2": "value2"}));
    });

    test("List -> application/json", () async {
      var req = new MockRequest("/types/list");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), contains("application/json"));
      expect(conv.JSON.decode(resp.mockContent),
          equals(["value1", "value2", "value3"]));
    });

    test("null -> empty response", () async {
      var req = new MockRequest("/types/null");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), isNull);
      expect(resp.mockContent, isEmpty);
    });

    test("Future -> (wait its completion)", () async {
      var req = new MockRequest("/types/future");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), contains("application/json"));
      expect(conv.JSON.decode(resp.mockContent),
          equals({"key1": "value1", "key2": "value2"}));
    });

    test("other types -> text/plain", () async {
      var req = new MockRequest("/types/other");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), contains("text/plain"));
      expect(resp.mockContent, equals("other_type"));
    });

    test("File -> (MimeType of the file)", () async {
      var req = new MockRequest("/types/file");
      var resp = await dispatch(req);
      expect(resp.headers.value("content-type"), contains("application/json"));
      expect(conv.JSON.decode(resp.mockContent), equals({"key": "value"}));
    });

    test("Shelf Response", () async {
      var req = new MockRequest("/types/shelf_response");
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("target_executed"));
    });
  });

  group("Route arguments:", () {
    setUp(() => redstoneSetUp([#arguments]));
    tearDown(redstoneTearDown);

    test("path parameters", () async {
      var req = new MockRequest("/args/arg/1/1.2");
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals({
            "arg1": "arg",
            "arg2": 1,
            "arg3": 1.2,
            "arg4": null,
            "arg5": "arg5"
          }));
    });

    test("path parameters with named arguments", () async {
      var req = new MockRequest("/named_args/arg1/arg2");
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals(
              {"arg1": "arg1", "arg2": "arg2", "arg3": null, "arg4": "arg4"}));
    });

    test("query parameters", () async {
      var req = new MockRequest("/query_args",
          queryParameters: {"arg1": "arg1", "arg2": "1", "arg3": "1.2"});
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals({
            "arg1": "arg1",
            "arg2": 1,
            "arg3": 1.2,
            "arg4": null,
            "arg5": "arg5",
            "arg6": null,
            "arg7": "arg7"
          }));
    });

    test("query parameters with list", () async {
      var req = new MockRequest("/query_args_with_list",
          queryParameters: {
            "arg1": ["a", "b", "c"],
            "arg2": ["1", "2", "3"],
            "arg3": ["1.1", "2.2", "3.3"],
            "arg4": ["1", "2.22", "3.33"],
            "arg5": ["0", "1", "true"],
          });
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals({
            "arg1": ["a", "b", "c"],
            "arg2": [1, 2, 3],
            "arg3": [1.1, 2.2, 3.3],
            "arg4": [1, 2.22, 3.33],
            "arg5": [false, false, true]
          }));
    });

    test("path and query parameters", () async {
      var req = new MockRequest("/path_query_args/arg1",
          queryParameters: {"arg": "arg2"});
      var resp = await dispatch(req);
      expect(conv.JSON.decode(resp.mockContent),
          equals({"arg": "arg1", "qArg": "arg2"}));
    });

    test("query parameters with num type", () async {
      var req = new MockRequest("/query_args_with_num",
          queryParameters: {"arg1": "1", "arg2": "1.5"});
      var resp = await dispatch(req);
      expect(conv.JSON.decode(resp.mockContent),
          equals({"arg1": 1, "arg2": 1.5,}));
    });

    test("query parameters with named arguments", () async {
      var req = new MockRequest("/named_query_args",
          queryParameters: {"arg1": "arg1", "arg2": "arg2"});
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals({
            "arg1": "arg1",
            "arg2": "arg2",
            "arg3": null,
            "arg4": "arg4",
            "arg5": null,
            "arg6": "arg6"
          }));
    });

    test("path and query parameters", () async {
      var req = new MockRequest("/path_query_args/arg1",
          queryParameters: {"arg": "arg2"});
      var resp = await dispatch(req);
      expect(conv.JSON.decode(resp.mockContent),
          equals({"arg": "arg1", "qArg": "arg2"}));
    });

    test("request content as JSON", () async {
      var req = new MockRequest("/json/arg1",
          method: POST, bodyType: JSON, body: {"key": "value"});
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals({
            "arg": "arg1",
            "json": {"key": "value"}
          }));
    });

    test("request content as FORM", () async {
      var req = new MockRequest("/form/arg1",
          method: POST, bodyType: FORM, body: {"key": "value"});
      var resp = await dispatch(req);
      expect(
          conv.JSON.decode(resp.mockContent),
          equals({
            "arg": "arg1",
            "form": {"key": "value"}
          }));
    });

    test("request content as TEXT", () async {
      var req = new MockRequest("/text/arg1",
          method: POST, bodyType: TEXT, body: "plain text");
      var resp = await dispatch(req);
      expect(conv.JSON.decode(resp.mockContent),
          equals({"arg": "arg1", "text": "plain text"}));
    });

    test("request content as JSON using DynamicMap", () async {
      var req = new MockRequest("/jsonDynamicMap",
          method: POST,
          bodyType: JSON,
          body: {
            "key": {"innerKey": "value"}
          });
      var resp = await dispatch(req);
      expect(conv.JSON.decode(resp.mockContent), equals({"key": "value"}));
    });

    test("request attributes", () async {
      var req = new MockRequest("/attr/arg1");
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("name_attr arg1 1"));
    });
  });

  group("Error handling:", () {
    setUp(() => redstoneSetUp([#errors]));
    tearDown(redstoneTearDown);

    test("wrong method", () async {
      var req = new MockRequest("/wrong_method");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(405));
    });

    test("wrong type", () async {
      var req = new MockRequest("/wrong_type",
          method: POST, bodyType: FORM, body: {"key": "value"});
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(400));
    });

    test("wrong value", () async {
      var req = new MockRequest("/wrong_value/not_int");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(400));
    });

    test("route error", () async {
      var req = new MockRequest("/route_error");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(500));
      expect(resp.mockContent, equals("server_error"));
    });

    test("async route error", () async {
      var req = new MockRequest("/async_route_error");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(500));
      expect(resp.mockContent, equals("server_error"));
    });

    test("interceptor error", () async {
      var req = new MockRequest("/interceptor_error");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(500));
      expect(resp.mockContent, equals("server_error"));
    });

    test("async interceptor error", () async {
      var req = new MockRequest("/async_interceptor_error");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(500));
      expect(resp.mockContent, equals("server_error"));
    });

    test("resource not found", () async {
      var req = new MockRequest("/not_found");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(404));
      expect(resp.mockContent, equals("not_found"));
    });

    test("Find error handler by path", () async {
      var req = new MockRequest("/sub_handler");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(500));
      expect(resp.mockContent, equals("server_error sub_error_handler"));
    });

    test("Error response", () async {
      var req = new MockRequest("/error_response");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(400));
      expect(resp.mockContent, equals("handling: error_response"));
    });
  });

  group("Chain:", () {
    setUp(() => redstoneSetUp([#interceptors]));
    tearDown(redstoneTearDown);

    test("interceptors", () async {
      var req = new MockRequest("/target");
      var req2 = new MockRequest("/parse_body");
      var parsebodyget = new MockRequest("/parse_body", contentType: 'application/json', body: null );

      var resp = await dispatch(req);
      expect(
          resp.mockContent,
          equals(
              "before_interceptor1|before_interceptor2|target_executed|after_interceptor2|after_interceptor1"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("target_executed"));
      expect(resp.statusCode, equals(200));

      resp = await dispatch(parsebodyget);
      expect(resp.mockContent, equals("target_executed"));
    });

    test("interrupt", () async {
      var req = new MockRequest("/interrupt");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(401));
      expect(resp.mockContent, equals("chain_interrupted"));
    });

    test("redirect", () async {
      var req = new MockRequest("/redirect");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(302));
    });

    test("abort", () async {
      var req = new MockRequest("/abort");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(401));
    });

    test("basic auth parse", () async {
      var req = new MockRequest("/basicauth_data",
          basicAuth: new Credentials("Aladdin", "open sesame"));
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(200));
      expect(resp.mockContent, equals("basic_auth"));
    });
  });

  group("dependency injection:", () {
    setUp(() {
      addModule(new Module()..bind(A)..bind(B)..bind(C));
      return redstoneSetUp([#dependency_injection]);
    });
    tearDown(redstoneTearDown);

    test("Routes and interceptors", () async {
      var req = new MockRequest("/di");
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("value_a value_b value_a value_b"));
    });

    test("Groups", () async {
      var req = new MockRequest("/group/di");
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("value_a value_b"));
    });

    test("Error handlers", () async {
      var req = new MockRequest("/invalid_path");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(404));
      expect(resp.mockContent, equals("value_a value_b"));
    });
  });

  group("install library:", () {
    setUp(() => redstoneSetUp([#install_lib]));
    tearDown(redstoneTearDown);

    test("URL prefix", () async {
      var req = new MockRequest("/prefix/route");
      var req2 = new MockRequest("/prefix/group/route");
      var req3 = new MockRequest("/prefix/error");

      var resp = await dispatch(req);
      expect(resp.mockContent, equals("interceptor_executed target_executed"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("interceptor_executed target_executed"));
      resp = await dispatch(req3);
      expect(resp.mockContent, equals("error_handler_executed"));
    });

    test("Chain", () async {
      var req = new MockRequest("/chain/route");
      var resp = await dispatch(req);
      expect(
          resp.mockContent,
          equals(
              "root interceptor_1 interceptor_2 interceptor_3 interceptor_4 target "));
    });

    test("@Ignore", () async {
      var req = new MockRequest("/ignore");
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(404));
    });
  });

  group("Plugins:", () {
    setUp(() {
      addPlugin(fromJsonPlugin);
      addPlugin(toJsonPlugin);
      addPlugin(testPlugin);
      addPlugin(wrapperPlugin);
      return redstoneSetUp([#plugins]);
    });
    tearDown(redstoneTearDown);

    test("Parameter provider", () async {
      var req = new MockRequest("/user",
          method: POST,
          bodyType: JSON,
          body: {"name": "name", "username": "username"});
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("name: name username: username"));
    });

    test("Parameter provider - exception", () async {
      var req = new MockRequest("/user",
          method: POST,
          bodyType: FORM,
          body: {"name": "name", "username": "username"});
      var resp = await dispatch(req);
      expect(resp.statusCode, equals(400));
    });

    test("Response processor", () async {
      var req = new MockRequest("/user/find");
      var resp = await dispatch(req);
      expect(conv.JSON.decode(resp.mockContent),
          equals({"name": "name", "username": "username"}));
    });

    test("Routes", () async {
      var req = new MockRequest("/route/value");
      var req2 = new MockRequest("/error");

      var resp = await dispatch(req);
      expect(resp.mockContent, equals("interceptor value"));
      resp = await dispatch(req2);
      expect(resp.mockContent, equals("error_handler"));
    });

    test("Route wrapper", () async {
      var reqFunctionWrapper = new MockRequest("/test_wrapper");
      var reqGroupWrapper = new MockRequest("/test_group_wrapper/test_wrapper");
      var reqMethodWrapper =
          new MockRequest("/test_method_wrapper/test_wrapper");
      var reqRedirectWrapper = new MockRequest("/test_wrapper/redirect");

      var resp = await dispatch(reqFunctionWrapper);
      expect(resp.mockContent, equals("response: target executed"));
      resp = await dispatch(reqGroupWrapper);
      expect(resp.mockContent, equals("response: target executed"));
      resp = await dispatch(reqMethodWrapper);
      expect(resp.mockContent, equals("response: target executed"));
      resp = await dispatch(reqRedirectWrapper);
      expect(resp.mockContent, equals("response: target executed"));
    });
  });

  group("Plugins:", () {
    tearDown(redstoneTearDown);

    test("Find functions, classes and methods", () async {
      var completer = new Completer();

      addPlugin((Manager manager) {
        var expectedFunctions = [
          new CapturedType.fromValues(
              #annotatedFunction, const TestAnnotation())
        ].toSet();
        var expectedClasses = [
          new CapturedType.fromValues(#AnnotatedClass, const TestAnnotation())
        ].toSet();
        var expectedMethods = [
          new CapturedType.fromValues(#annotatedMethod, const TestAnnotation())
        ].toSet();

        var functions = manager
            .findFunctions(TestAnnotation)
            .map((t) => new CapturedType(t))
            .toSet();
        var classes = manager
            .findClasses(TestAnnotation)
            .map((t) => new CapturedType(t))
            .toSet();
        var methods = manager
            .findMethods(reflectClass(AnnotatedClass), TestAnnotation)
            .map((t) => new CapturedType(t))
            .toSet();

        expect(functions, equals(expectedFunctions));
        expect(classes, equals(expectedClasses));
        expect(methods, equals(expectedMethods));

        completer.complete();
      });

      return redstoneSetUp([#plugins]).then((_) => completer.future);
    });
  });

  group("Plugins:", () {
    tearDown(redstoneTearDown);

    test("Metadata access", () {
      var completer = new Completer();

      var setRoutes;
      var setInterceptors;
      var setErrorHandlers;

      void extractMetadata(ServerMetadata serverMetadata) {
        setRoutes = new Set();
        setInterceptors = new Set();
        setErrorHandlers = new Set();

        serverMetadata.routes.forEach((r) {
          setRoutes.add(r.conf.urlTemplate);
        });
        serverMetadata.interceptors.forEach((i) {
          setInterceptors.add(i.conf.urlPattern);
        });
        serverMetadata.errorHandlers.forEach((e) {
          setErrorHandlers.add(e.conf.statusCode);
        });
      }

      void extractGroupMetadata(GroupMetadata groupMetadata) {
        setRoutes = new Set();
        setInterceptors = new Set();
        setErrorHandlers = new Set();

        groupMetadata.routes.forEach((r) {
          setRoutes.add(r.conf.urlTemplate);
        });
        groupMetadata.interceptors.forEach((i) {
          setInterceptors.add(i.conf.urlPattern);
        });
        groupMetadata.errorHandlers.forEach((e) {
          setErrorHandlers.add(e.conf.statusCode);
        });
      }

      var expectedRoutes = new Set()..add("/route1")..add("/route2");
      var expectedInterceptors = new Set()..add("/interceptor");
      var expectedErrorHandlers = new Set()..add(333);

      addPlugin((manager) {
        try {
          extractMetadata(manager.serverMetadata);

          expect(setRoutes, equals(expectedRoutes));
          expect(setInterceptors, equals(expectedInterceptors));
          expect(setErrorHandlers, equals(expectedErrorHandlers));

          expect(manager.serverMetadata.groups.length, equals(1));

          var groupMetadata = manager.serverMetadata.groups[0];
          extractGroupMetadata(groupMetadata);

          expect(setRoutes, equals(expectedRoutes));
          expect(setInterceptors, equals(expectedInterceptors));
          expect(setErrorHandlers, equals(expectedErrorHandlers));

          completer.complete();
        } catch (e) {
          completer.completeError(e);
        }
      });

      return redstoneSetUp([#inspect]).then((_) => completer.future);
    });
  });

  group("Shelf:", () {
    tearDown(redstoneTearDown);

    test("Middlewares", () async {
      addShelfMiddleware(
          shelf.createMiddleware(responseHandler: (shelf.Response resp) {
        return resp
            .readAsString()
            .then((value) => new shelf.Response.ok("middleware_1 $value"));
      }));
      addShelfMiddleware(
          shelf.createMiddleware(responseHandler: (shelf.Response resp) {
        return resp
            .readAsString()
            .then((value) => new shelf.Response.ok("middleware_2 $value"));
      }));
      await redstoneSetUp([#routes]);

      MockRequest req = new MockRequest("/path/arg");
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("middleware_1 middleware_2 main_route"));
    });

    test("Handler", () async {
      setShelfHandler((shelf.Request req) {
        return new shelf.Response.ok("handler_executed");
      });
      await redstoneSetUp([#routes]);

      MockRequest req = new MockRequest("/invalid_path");
      var resp = await dispatch(req);
      expect(resp.mockContent, equals("handler_executed"));
      expect(resp.statusCode, equals(200));
    });
  });
}
