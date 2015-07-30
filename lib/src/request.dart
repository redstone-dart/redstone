library redstone.src.request;

import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;

import 'dynamic_map.dart';
import 'constants.dart';

/// The request information and content.
abstract class Request {

  /// The original [Uri] for the request.
  Uri get requestedUri;

  /// See [shelf.Request.url]
  Uri get url;

  /// See [shelf.Request.handlerPath]
  String get handlerPath;

  /// The method, such as 'GET' or 'POST', for the request (read-only).
  String get method;

  /// Returns a list of query parameters
  DynamicMap<String, List<String>> get queryParameters;

  /// Returns a map of parameters in the URL
  ///
  /// This map is populated only when a route is called.
  /// The map's keys are the named paremeters defined in the
  /// URL template of the route.
  DynamicMap<String, String> get urlParameters;

  /// The body type, such as 'JSON', 'TEXT' or 'FORM'
  BodyType get bodyType;

  /// Indicate if this request is multipart
  bool get isMultipart;

  /// The request body.
  ///
  /// [body] can be a [Map], [List] or [String].
  dynamic get body;

  /// The headers of the request
  DynamicMap get headers;

  /// The session for the given request (read-only).
  HttpSession get session;

  /// Map of request attributes.
  ///
  /// Attributes are objects that can be shared between
  /// interceptors and routes
  DynamicMap get attributes;

  /// The original Shelf request
  shelf.Request get shelfRequest;

  /// Parse authorization header (HTTP Basic Authentication).
  Credentials parseAuthorizationHeader();
}

/// A chain of handlers.
///
/// A handler can be a route, interceptor, error handler, shelf middleware
/// or shelf handler.
abstract class Chain {

  /// Returns the last error thrown by a handler
  /// (an interceptor, route, error handler or shelf handler)
  dynamic get error;

  /// Returns the stack trace of the last error thrown by a handler
  /// (an interceptor, route, error handler or shelf handler)
  dynamic get stackTrace;

  /// Calls the next element of this chain (an interceptor, route or shelf handler)
  Future<shelf.Response> next();

  /// Creates a new response object
  ///
  /// If [responseValue] is provided, it'll be serialized and written to the response body. If
  /// [responseType] is provided, it'll be set as the content-type of the response.
  Future<shelf.Response> createResponse(int statusCode,
      {Object responseValue, String responseType});

  /// Dispatch a GET request for [url].
  ///
  /// Only routes, shelf handlers and error handlers bound to [url]
  /// will be invoked. Shelf middlewares and interceptors
  /// won't be triggered.
  Future<shelf.Response> forward(String url, {Map<String, String> headers});

  /// Creates a new response for [statusCode]. If there is an
  /// ErrorHandler registered for this status code, it will
  /// be invoked.
  Future<shelf.Response> abort(int statusCode);

  /// Creates a new response with an 302 status code.
  shelf.Response redirect(String url);
}

/// User credentials (HTTP Basic Authentication)
class Credentials {
  String username;
  String password;

  Credentials(this.username, this.password);
}

/// An error response.
///
/// If a route returns or throws an [ErrorResponse], then
/// the framework will serialize [error], and create a
/// response with status [statusCode].
class ErrorResponse {
  final int statusCode;
  final Object error;

  ErrorResponse(this.statusCode, this.error);
}
