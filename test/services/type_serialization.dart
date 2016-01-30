library type_serialization;

import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/types/string")
String stringType() => "string";

@Route("/types/map")
Map mapType() => {"key1": "value1", "key2": "value2"};

@Route("/types/list")
List<String> listType() => ["value1", "value2", "value3"];

@Route("/types/null")
Null nullType() => null;

@Route("/types/future")
Future futureType() => new Future(() => mapType());

@Route("/types/other")
_OtherType otherType() => new _OtherType();

@Route("/types/file")
File fileType() => new _MockFile();

@Route("/types/shelf_response")
shelf.Response shelfResponse() => new shelf.Response.ok("target_executed");

class _OtherType {
  String toString() => "other_type";
}

class _MockFile implements File {
  Stream<List<int>> _stream =
      new Stream.fromIterable([UTF8.encode(r'{"key": "value"}')]);

  String get path => "test.json";

  Stream<List<int>> openRead([int start, int end]) => _stream;

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
