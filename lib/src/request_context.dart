library redstone.src.request_context;

import 'dart:async';

import 'package:shelf/shelf.dart' as shelf;

import 'request.dart';
import 'request_parser.dart';

const String REQUEST_CONTEXT_KEY = "req_ctx";

class RequestContext {
  Chain chain;
  RequestParser request;
  shelf.Response response = new shelf.Response.ok(null);
  StackTrace lastStackTrace;

  RequestContext(this.request);
}

RequestContext get currentContext => Zone.current[REQUEST_CONTEXT_KEY];

class RequestException implements Exception {
  final String handler;
  final String message;
  final int statusCode;

  RequestException(this.handler, this.message, [this.statusCode = 400]);

  String toString() => "RequestException($statusCode): [$handler] $message";
}
