library server_tests;

import 'dart:convert';

import 'package:unittest/unittest.dart';

import 'package:bloodless/server.dart' as app;
import 'package:bloodless/mocks.dart';
import 'package:logging/logging.dart';

import 'services/type_serialization.dart';

main() {
  
  //app.setupConsoleLog(Level.ALL);
  
  group("When a route is executed, the returned value must be serialized according to its type:", () {
    
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
  
}