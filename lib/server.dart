library redstone_server;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'dart:convert' as conv;
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:mime/mime.dart';
import 'package:route_hierarchical/url_matcher.dart';
import 'package:route_hierarchical/url_template.dart';
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';
import 'package:stack_trace/stack_trace.dart';

import 'package:di/di.dart';

import 'query_map.dart';

part 'src/metadata.dart';
part 'src/logger.dart';
part 'src/exception.dart';
part 'src/setup_impl.dart';
part 'src/plugin_impl.dart';
part 'src/server_impl.dart';
part 'src/blacklist.dart';
part 'src/http_body_parser.dart';

const String GET = "GET";
const String POST = "POST";
const String PUT = "PUT";
const String DELETE = "DELETE";

const String JSON = "json";
const String FORM = "form";
const String TEXT = "text";
const String BINARY = "binary";

const String ROUTE = "ROUTE";
const String INTERCEPTOR = "INTERCEPTOR";
const String ERROR_HANDLER = "ERROR_HANDLER";

const String _DEFAULT_ADDRESS = "0.0.0.0";
const int _DEFAULT_PORT = 8080;


/// The request's information and content.
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

  ///The method, such as 'GET' or 'POST', for the request (read-only).
  String get method;

  ///The query parameters associated with the request
  QueryMap get queryParams;

  ///The body type, such as 'JSON', 'TEXT' or 'FORM'
  String get bodyType;

  ///Indicate if this request is multipart
  bool get isMultipart;

  /**
   * The request body.
   *
   * [body] can be a [Map], [List] or [String]. See [HttpBody]
   * for more information.
   */
  dynamic get body;

  ///The headers of the request
  QueryMap get headers;

  ///The session for the given request (read-only).
  HttpSession get session;

  /**
   * Map of request attributes.
   *
   * Attributes are objects that can be shared between
   * interceptors and routes
   */
  QueryMap get attributes;

  ///The original Shelf request
  shelf.Request get shelfRequest;

}

/// A request whose body was not fully read yet
abstract class UnparsedRequest extends Request {

  void parseBodyType();

  Future parseBody();

  HttpRequest get httpRequest;

  void set shelfRequest(shelf.Request req);

}

/**
 * HttpRequest parser
 */
class HttpRequestParser {

  String _bodyType;
  bool _isMultipart = false;
  ContentType _contentType;
  HttpBody _requestBody;
  Future _bodyParsed = null;

  String get bodyType => _bodyType;
  bool get isMultipart => _isMultipart;
  get body => _requestBody != null ? _requestBody.body : null;

  void parseHttpRequestBodyType(Map<String, String> headers) {
    var ct = headers["content-type"];
    if (ct == null) {
      return;
    }
    _contentType = ContentType.parse(ct);
    if (_contentType == null) {
      return;
    }
    switch (_contentType.primaryType) {
      case "text":
        _bodyType = TEXT;
        break;
      case "application":
        switch (_contentType.subType) {
          case "json":
            _bodyType = JSON;
            break;
          case "x-www-form-urlencoded":
            _bodyType = FORM;
            break;
        }
        break;
      case "multipart":
        _isMultipart = true;
        switch (_contentType.subType) {
          case "form-data":
            _bodyType = FORM;
            break;
        }
        break;
      default:
        _bodyType = "binary";
        break;
    }
  }

  Future parseHttpRequestBody(Stream<List<int>> body) {
    if (_bodyParsed == null) {
      _bodyParsed = _parseRequestBody(body, _contentType).then((HttpBody reqBody) {
          _requestBody = reqBody;
          return reqBody.body;
      });
    }

    return _bodyParsed;
  }
}

/**
 * The chain of the given request.
 *
 * A chain is composed of a target and 0 or more interceptors,
 * and it can be directly manipulated only by interceptors.
 */
abstract class Chain {

  ///The error object thrown by the target
  dynamic error;

  /**
   * Call the next element of this chain (an interceptor or a target)
   *
   * The given [callback] will be executed when all following elements
   * in the chain are completed. The callback can return a [Future].
   */
  void next([callback()]);

  ///Interrupt this chain. If [statusCode] or [responseValue] is provided,
  ///a new Response will be created.
  void interrupt({int statusCode, Object responseValue, String responseType});

  ///Returns true if this chain was interrupted
  bool get interrupted;

}

/**
 * An error response.
 *
 * If a route returns or throws an [ErrorResponse], then
 * the framework will serialize [error], and create a
 * response with status [statusCode].
 */
class ErrorResponse {

  final int statusCode;
  final Object error;

  ErrorResponse(this.statusCode, this.error);

}

/// User credentials from request
class Credentials {

  String username;
  String password;

  Credentials(this.username, this.password);

}

/**
 * The request's information and content.
 *
 * Since each request run in it's own [Zone], it's completely safe
 * to access this object at any time, even in async callbacks.
 */
Request get request => Zone.current[#request];

/// The [Response] object, used for sending back the response to the client.
shelf.Response get response => Zone.current[#state].response;

/// The [Response] object, used for sending back the response to the client.
void set response(shelf.Response value) {
  Zone.current[#state].response = value;
}

/**
 * The request's chain.
 *
 * Since each request run in its own [Zone], it's completely safe
 * to access this object at any time, even in async callbacks.
 */
Chain get chain => Zone.current[#chain];

/**
 * Abort the current request.
 *
 * If there is an ErrorHandler registered to [statusCode], it
 * will be invoked. Otherwise, the default ErrorHandler will be invoked.
 */
void abort(int statusCode) {
  if (chain.interrupted) {
    throw new ChainException(request.url.path, "invalid state: chain already interrupted");
  }
  Zone.current[#state].requestAborted = true;
  _notifyError(statusCode, request.url.path).then((_) {
    chain.interrupt();
  });
}

/**
 * Redirect the user to [url].
 *
 * [url] can be absolute, or relative to the url of the current request.
 */
void redirect(String url) {
  if (chain.interrupted) {
    throw new ChainException(request.url.path, "invalid state: chain already interrupted");
  }
  response = new shelf.Response.found(request.url.resolve(url));
  chain.interrupt();
}

/// Parse authorization header from request.
Credentials parseAuthorizationHeader() {
  if (request.headers[HttpHeaders.AUTHORIZATION] != null) {
    String authorization = request.headers[HttpHeaders.AUTHORIZATION];
    List<String> tokens = authorization.split(" ");
    if ("Basic" == tokens[0]) {
      String auth = conv.UTF8.decode(CryptoUtils.base64StringToBytes(tokens[1]));
      int idx = auth.indexOf(":");
      if (idx > 0) {
        String username = auth.substring(0, idx);
        String password = auth.substring(idx + 1);
        return new Credentials(username, password);
      }
    }
  }
  return null;
}

/**
 * Http Basic access authentication
 *
 * Returns true if the current request contains the authorization header for [username] and [password].
 * If authentication fails and [realm] is provided, then a new response with 401 status code and
 * a 'www-authenticate' header will be created.
 */
bool authenticateBasic(String username, String password, {String realm}){
  bool r = false;
  var headers = request.headers;
  if (request.headers[HttpHeaders.AUTHORIZATION] != null) {
    String authorization = request.headers[HttpHeaders.AUTHORIZATION];
    List<String> tokens = authorization.split(" ");
    String auth = CryptoUtils.bytesToBase64(conv.UTF8.encode("$username:$password"));
    if ("Basic" == tokens[0] && auth == tokens[1]) {
      r = true;
    }
  }
  if (!r) {
    if (realm != null) {
      Map headers = new Map.from(response.headers);
      headers[HttpHeaders.WWW_AUTHENTICATE] = 'Basic realm="$realm"';
      response = new shelf.Response(HttpStatus.UNAUTHORIZED,
          body: response.read(), headers: headers);
    }
  }

  return r;
}

/**
 * Register a module for dependency injection.
 *
 * All modules must be registered before invoking the [start] or
 * [setUp] methods.
 */
void addModule(Module module) {
  _modules.add(module);
}

/**
 * Register a plugin.
 *
 * All plugins must be registered before invoking the [start] or
 * [setUp] methods.
 */
void addPlugin(RedstonePlugin plugin) {
  _plugins.add(plugin);
}

/**
 * Register a Shelf Middleware.
 *
 * Middlewares are invoked before any interceptor or route.
 */
void addShelfMiddleware(shelf.Middleware middleware) {
  if (_shelfPipeline == null) {
    _shelfPipeline = _buildShelfPipeline();
  }
  _shelfPipeline = _shelfPipeline.addMiddleware(middleware);
}

/**
 * Register a Shelf Handler.
 *
 * The [handler] will be invoked when all interceptors are
 * completed, and no route is found for the requested URL.
 */
void setShelfHandler(shelf.Handler handler) {
  _defaultHandler = handler;
}

/**
 * Start the server.
 *
 * The [address] can be a [String] or an [InternetAddress].
 *
 * When [secureOptions] is specified the server will use a secure https connection.
 * [secureOptions] is a map of named arguments forwarded to [HttpServer.bindSecure].
 */
Future<HttpServer> start({address: _DEFAULT_ADDRESS, int port: _DEFAULT_PORT,
                          Map<Symbol, dynamic> secureOptions}) {
  return new Future(() {

    setUp();

    Future<HttpServer> serverFuture;

    if (secureOptions == null) {
      serverFuture = HttpServer.bind(address, port);
    } else {
      _logger.info("Using a secure connection with options: $secureOptions");
      serverFuture = Function.apply(HttpServer.bindSecure, [address, port], secureOptions);
    }

    return serverFuture.then((server) {
      server.listen((HttpRequest req) {
        _logger.fine("Received request for: ${req.uri}");
        _dispatchRequest(new _RequestImpl(req)).catchError((e, s) {
          _logger.severe("Failed to handle request for ${req.uri}", e, s);
        });
      });

      _logger.info("Running on $address:$port");
      return server;
    });
  });
}

/**
 * Serve a [Stream] of [HttpRequest]s.
 *
 * [HttpServer] implements [Stream<HttpRequest>], so it can be passed directly
 * to [serveRequests].
 */
void serveRequests(Stream<HttpRequest> requests) {

  setUp();

  requests.listen((HttpRequest req) {

    _logger.fine("Received request for: ${req.uri}");
    _dispatchRequest(new _RequestImpl(req)).catchError((e, s) {
      _logger.severe("Failed to handle request for ${req.uri}", e, s);
    });

  });

}

/**
 * Handle a [HttpRequest].
 *
 * Be sure to call [setUp] before handling requests
 * with this method.
 */
Future handleRequest(HttpRequest request) {
  _logger.fine("Received request for: ${request.uri}");
  return _dispatchRequest(new _RequestImpl(request)).catchError((e, s) {
    _logger.severe("Failed to handle request for ${request.uri}", e, s);
  });
}

/**
 * Scan and initialize routes, interceptors and error handlers
 *
 * If [libraries] is provided, then the scan process will be limited
 * to those libraries.
 */
void setUp([List<Symbol> libraries]) {
  try {
    _scanHandlers(libraries);
  } catch (e) {
    _handleError("Failed to configure handlers.", e);
    rethrow;
  }
}

/**
 * Remove all modules, plugins, routes, interceptors and error handlers.
 *
 * This method is intended to be used in unit tests.
 */
void tearDown() {
  _clearHandlers();
}

/**
 * Dispatch a request.
 *
 * This method is intended to be used in unit tests, where you
 * can create new requests with [MockRequest]
 */
Future<HttpResponse> dispatch(UnparsedRequest request) =>
    _dispatchRequest(request);


/**
 * Allows to programmatically create routes, interceptors, error handlers,
 * parameter providers and response processors.
 *
 * To access a [Manager] instance, you need to create and register a [RedstonePlugin].
 */
abstract class Manager {

  /**
   * The server metadata, which contains all routes, interceptors,
   * error handlers and groups that composes this application.
   */
  ServerMetadata get serverMetadata;

  /**
   * Create a new route.
   */
  void addRoute(Route conf, String name, RouteHandler route, {String bodyType});

  /**
   * Create a new interceptor.
   */
  void addInterceptor(Interceptor conf, String name, Handler interceptor);

  /**
   * Create a new error handler.
   */
  void addErrorHandler(ErrorHandler conf, String name, Handler errorHandler);

  /**
   * Create a new parameter provider.
   *
   * [metadataType] is the annotation type that will trigger the provider.
   * [parameterProvider] is the function which will be invoked to create
   * the parameter's value. [handlerTypes] are the handler types that can use
   * this provider, and defaults to ROUTE.
   */
  void addParameterProvider(Type metadataType, ParamProvider parameterProvider,
                            {List<String> handlerTypes: const [ROUTE]});

  /**
   * Create a new response processor.
   *
   * [metadataType] is the annotation type that will trigger the processor.
   * [processor] is the function which will be invoked to transform the returned
   * value. If [includeGroups] is true and the annotation is used on a group, then
   * all group's routes will use the processor.
   */
  void addResponseProcessor(Type metadataType, ResponseProcessor processor,
                            {bool includeGroups: false});

  /**
   * Create a new route wrapper.
   *
   * Wrap all routes that are annotated with [metadataType].
   * If [includeGroups] is true and the annotation is used on a group,
   * then all group's routes will be wrapped as well.
   *
   * Usage:
   *
   *      //wrap all routes annotated with @MyAnnotation()
   *      manager.addRouteWrapper(MyAnnotation, (myAnnotation, pathSegments, injector, request, route) {
   *
   *        //here you can prevent the route from executing, or inspect and modify
   *        //the returned value
   *
   *        return route(pathSegments, injector, request);
   *
   *      });
   */
  void addRouteWrapper(Type metadataType, RouteWrapper wrapper,
                       {bool includeGroups: false});

  ///Retrieve installed shelf handler
  shelf.Handler getShelfHandler();

  ///Set or replace the current installed shelf handler
  void setShelfHandler(shelf.Handler handler);

  /**
   * Create a new DI injector restricted to the scope of this plugin.
   *
   * The returned injector will be a child of the application injector.
   */
  Injector createInjector(List<Module> modules);

  ///Retrieve the application DI injector
  Injector getInjector();

  ///Find all functions annotated with [annotation]
  Iterable<AnnotatedType<MethodMirror>> findFunctions(Type annotation);

  ///Find all classes annotated with [annotation]
  Iterable<AnnotatedType<ClassMirror>> findClasses(Type annotation);

  ///Find all methods of [clazz] that are annotated with [annotation]
  Iterable<AnnotatedType<MethodMirror>> findMethods(ClassMirror clazz, Type annotation);

}

/**
 *
 *
 */
class AnnotatedType<T> {

  final T mirror;
  final Object metadata;

  AnnotatedType(this.mirror, this.metadata);

}

abstract class HandlerMetadata<T, M> {

  T get conf;

  M get mirror;

  List get metadata;

}

/**
 * Allow access to all installed routes, interceptors,
 * error handlers and groups that composes an application.
 */
abstract class ServerMetadata {

  /**
   * Returns the installed routes.
   *
   * This list contains routes which are bound to top level
   * functions. For routes that belongs to a group, see [groups];
   */
  List<RouteMetadata> get routes;

  /**
   * Returns the installed interceptors.
   *
   * This list contains interceptors which are bound to top level
   * functions. For interceptors that belongs to a group, see [groups];
   */
  List<InterceptorMetadata> get interceptors;

  /**
   * Returns the installed error handlers.
   *
   * This list contains error handlers which are bound to top level
   * functions. For error handlers that belongs to a group, see [groups];
   */
  List<ErrorHandlerMetadata> get errorHandlers;

  ///Returns all installed groups.
  List<GroupMetadata> get groups;

}

abstract class RouteMetadata implements HandlerMetadata<Route, MethodMirror> {

  ///The url pattern of this route
  String get urlRegex;

}

abstract class InterceptorMetadata implements
    HandlerMetadata<Interceptor, MethodMirror> { }

abstract class ErrorHandlerMetadata implements
    HandlerMetadata<ErrorHandler, MethodMirror> { }

abstract class GroupMetadata implements ServerMetadata,
                                        HandlerMetadata<Group, ClassMirror> { }

/**
 * A plugin is a function which can dynamically add new features
 * to an application.
 */
typedef void RedstonePlugin(Manager manager);

/// A route programmatically created by a plugin.
typedef dynamic RouteHandler(Map<String, String> pathSegments,
                             Injector injector, Request request);

/// A route wrapper created by a plugin.
typedef dynamic RouteWrapper(dynamic metadata,
                             Map<String, String> pathSegments,
                             Injector injector, Request request,
                             RouteHandler route);

/// An interceptor or error handler, programmatically created by a plugin.
typedef dynamic Handler(Injector injector);

/**
 * A parameter provider is a function that can create parameters
 * for routes, interceptors and error handlers.
 *
 * It can be used, for example, to automatically validate
 * and parse the request's body and arguments.
 */
typedef Object ParamProvider(dynamic metadata, Type paramType,
                             String handlerName, String paramName,
                             Request request, Injector injector);

/**
 * A response processor is a function, that can transform values
 * returned by routes.
 */
typedef Object ResponseProcessor(dynamic metadata, String handlerName,
                                 Object response, Injector injector);
