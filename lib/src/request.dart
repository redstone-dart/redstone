library redstone.src.request;

import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;

import 'dynamic_map.dart';
import 'metadata.dart';

/// The request information and content.
abstract class Request {

  /// The original [Uri] for the request.
  Uri get requestedUri;

  /// The remainder of the [requestedUri] path and query designating the virtual
  /// "location" of the request's target within the handler.
  ///
  /// [url] may be an empty, if [requestedUri] targets the handler
  /// root and does not have a trailing slash.
  ///
  /// [url] is never null. If it is not empty, it will start with `/`.
  ///
  /// [scriptName] and [url] combine to create a valid path that should
  /// correspond to the [requestedUri] path.
  Uri get url;

  /// The method, such as 'GET' or 'POST', for the request (read-only).
  String get method;

  /// The query parameters associated with the request
  DynamicMap<String, List<String>> get queryParams;
  
  /// 
  DynamicMap<String, String> get pathParams;

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

/// The chain of the given request.
///
/// A chain is composed of a target and 0 or more interceptors,
/// and it can be directly manipulated only by interceptors.
abstract class Chain {

  ///The error object thrown by the target
  dynamic get error;

  /// Call the next element of this chain (an interceptor or a route)
  Future<shelf.Response> next();

  ///Create a new response object
  ///
  ///If [responseValue] is provided, it'll be serialized and written to the response body. If
  ///[responseType] is provided, it'll be set as the content-type of the response.
  Future<shelf.Response> createResponse(int statusCode, {Object responseValue, String responseType});
  
  ///Dispatch a request for [url].
  ///
  ///Only routes, shelf handlers and error handlers bound to [url] 
  ///will be invoked. Shelf middlewares and interceptors
  ///won't be triggered.
  Future<shelf.Response> forward(String url);
  
  /// Abort the current request.
  ///
  /// If there is an ErrorHandler registered to [statusCode], it
  /// will be invoked. Otherwise, the default ErrorHandler will be invoked.
  Future<shelf.Response> abort(int statusCode);
  
  /// Redirect the user to [url].
  ///
  /// [url] can be absolute, or relative to the url of the current request.
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