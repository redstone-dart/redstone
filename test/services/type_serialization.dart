library type_serialization;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/types/string")
stringType() => "string";

@app.Route("/types/map")
mapType() => {"key1": "value1", "key2": "value2"};

@app.Route("/types/list")
listType() => ["value1", "value2", "value3"];

@app.Route("/types/null")
nullType() => null;

@app.Route("/types/future")
futureType() => new Future(() => mapType());

@app.Route("/types/other")
otherType() => new _OtherType();

@app.Route("/types/file")
fileType() => new _MockFile();

@app.Route("/types/shelf_response")
shelfResponse() => new shelf.Response.ok("target_executed");

class _OtherType {
  
  String toString() => "other_type";
  
}

class _MockFile implements File {
  
  Stream<List<int>> _stream = new Stream.fromIterable([UTF8.encode(r'{"key": "value"}')]);
  
  String get path => "test.json";
  
  Stream<List<int>> openRead([int start, int end]) => _stream;
  
  dynamic noSuchMethod(Invocation invocation) =>
        super.noSuchMethod(invocation);
}