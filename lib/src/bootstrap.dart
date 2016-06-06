library redstone.src.bootstrap;

import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart' as shelf;
import 'package:di/di.dart';

import 'request.dart';
import 'request_context.dart';
import 'plugin.dart';
import 'scanner.dart';
import 'processor.dart';
import 'router.dart';
import 'server_context.dart';
import 'logger.dart';
import 'request_mock.dart';
import 'http_mock.dart';

const String defaultAddress = "0.0.0.0";
const int defaultPort = 8080;

List<Module> _modules = [];
List<RedstonePlugin> _plugins = [];
ShelfContext _shelfContext = new ShelfContext();

Router _router;
Router get router => _router;

/// By default, redstone generates an error page whenever
/// a response with status code less than 200, or greater
/// or equal than 400, is returned. To prevent this
/// behavior, set this flag to false.
bool showErrorPage = true;

/// Returns the current request
Request get request => currentContext.request;

/// Returns the current response
shelf.Response get response => currentContext.response;

/// Sets a new response object
void set response(shelf.Response value) {
  currentContext.response = value;
}

/// Returns the current request chain
Chain get chain => currentContext.chain;

/// Creates a new response for [statusCode]. If there is an
/// ErrorHandler registered for this status code, it will
/// be invoked.
Future<shelf.Response> abort(int statusCode) =>
    currentContext.chain.abort(statusCode);

/// Creates a new response with an 302 status code.
shelf.Response redirect(String url) => currentContext.chain.redirect(url);

/// Register a module for dependency injection.
///
/// All modules must be registered before invoking the [start] or
/// [redstoneSetUp] methods.
void addModule(Module module) {
  _modules.add(module);
}

/// Register a plugin.
///
/// All plugins must be registered before invoking the [start] or
/// [redstoneSetUp] methods.
void addPlugin(RedstonePlugin plugin) {
  _plugins.add(plugin);
}

/// Register a Shelf Middleware.
///
/// Middlewares are invoked before any interceptor or route.
void addShelfMiddleware(shelf.Middleware middleware) {
  _shelfContext.middlewares.add(middleware);
}

/// Register a Shelf Handler.
///
/// The [handler] will be invoked when all interceptors are
/// completed, and no route is found for the requested URL.
void setShelfHandler(shelf.Handler handler) {
  _shelfContext.handler = handler;
}

/// Start the server.
///
/// The [address] can be a [String] or an [InternetAddress].
///
/// If [autoCompress] is true, the server will use gzip to compress the content
/// when possible.
///
/// The optional argument [shared] can be used to perform additional binds to the same
/// [address] and [port], from different isolates.
///
/// If [logSetUp] is false, the server won't create an log entry for every handler
/// configured. By default, it's setted to true.
///
/// When [secureOptions] is specified the server will use a secure https connection.
/// [secureOptions] is a map of named arguments forwarded to [HttpServer.bindSecure].
Future<HttpServer> start(
    {String address: defaultAddress,
    int port: defaultPort,
    bool autoCompress: false,
    bool shared: false,
    bool logSetUp: true,
    Map<Symbol, dynamic> secureOptions}) async {
  await redstoneSetUp();

  HttpServer server;
  if (secureOptions == null) {
    server = await HttpServer.bind(address, port, shared: shared);
  } else {
    redstoneLogger
        .info("Using a secure connection with options: $secureOptions");
    secureOptions[#shared] = shared;
    SecurityContext context = secureOptions[#context];
    secureOptions.remove(#context);

    server =
        await Function.apply(HttpServer.bindSecure, [address, port, context]);
  }

  server.autoCompress = autoCompress;
  server.listen((HttpRequest req) {
    redstoneLogger.fine("Received request for: ${req.uri}");
    _router.handleRequest(req);
  });

  redstoneLogger.info("Running on $address:$port");
  return server;
}

/// Serve a [Stream] of [HttpRequest]s.
///
/// [HttpServer] implements [Stream<HttpRequest>], so it can be passed directly
/// to [serveRequests].
Future serveRequests(Stream<HttpRequest> requests) async {
  await redstoneSetUp();

  requests.listen((HttpRequest req) {
    redstoneLogger.fine("Received request for: ${req.uri}");
    _router.handleRequest(req);
  });
}

/// Handle a [HttpRequest].
///
/// Be sure to call [setUp] before handling requests
/// with this method.
Future handleRequest(HttpRequest request) async {
  redstoneLogger.fine("Received request for: ${request.uri}");
  await _router.handleRequest(request);
}

/// Scan and initialize routes, interceptors and error handlers
///
/// If [libraries] is provided, then the scan process will be limited
/// to those libraries.
///
/// If [logSetUp] is false, the server won't create an log entry for every handler
/// configured. By default, it's setted to true.
Future redstoneSetUp([List<Symbol> libraries, bool logSetUp = true]) async {
  var scanner = new Scanner(libraries);
  var processor =
      new Processor(scanner.scan(), _shelfContext, _modules, _plugins);
  _router = new Router(await processor.parse(), showErrorPage, logSetUp);
}

/// Remove all modules, plugins, routes, interceptors and error handlers.
///
/// This method is intended to be used in unit tests.
void redstoneTearDown() {
  _router = null;
  _modules = [];
  _plugins = [];
  _shelfContext = new ShelfContext();
}

/// Dispatch a request.
///
/// This method is intended to be used in unit tests, where you
/// can create new requests with [MockRequest]
Future<MockHttpResponse> dispatch(MockRequest request) async {
  await _router.dispatchRequest(request);
  return request.httpRequest.response;
}
