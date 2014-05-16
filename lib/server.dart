library redstone_server;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'dart:convert' as conv;
import 'dart:math';

import 'package:http_server/http_server.dart';
import 'package:mime/mime.dart';
import 'package:route_hierarchical/url_matcher.dart';
import 'package:route_hierarchical/url_template.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

import 'package:di/di.dart';
import 'package:di/auto_injector.dart';

part 'package:redstone/src/metadata.dart';
part 'package:redstone/src/logger.dart';
part 'package:redstone/src/exception.dart';
part 'package:redstone/src/setup_impl.dart';
part 'package:redstone/src/plugin_impl.dart';
part 'package:redstone/src/server_impl.dart';

const String GET = "GET";
const String POST = "POST";
const String PUT = "PUT";
const String DELETE = "DELETE";

const String JSON = "json";
const String FORM = "form";
const String TEXT = "text";

const String ROUTE = "ROUTE";
const String INTERCEPTOR = "INTERCEPTOR";
const String ERROR_HANDLER = "ERROR_HANDLER";

const String _DEFAULT_ADDRESS = "0.0.0.0";
const int _DEFAULT_PORT = 8080;
const String _DEFAULT_STATIC_DIR = "../web";
const List<String> _DEFAULT_INDEX_FILES = const ["index.html"];

/**
 * The request's information and content.
 */
abstract class Request {

  ///The method, such as 'GET' or 'POST', for the request (read-only).
  String get method;

  ///The query parameters associated with the request
  Map<String, String> get queryParams;

  ///The body type, such as 'JSON', 'TEXT' or 'FORM'
  String get bodyType;
  
  ///Indicate if this request is multipart
  bool get isMultipart;

  /**
   * The request body.
   *
   * [body] can be a [Map], [List] or [String]. See [HttpRequestBody]
   * for more information.
   */ 
  dynamic get body;

  ///The headers of the request
  HttpHeaders get headers;

  ///The session for the given request (read-only).
  HttpSession get session;
  
  /**
   * Map of request attributes.
   * 
   * Attributes are objects that can be shared between
   * interceptors and routes
   */
  Map get attributes;

  ///The [HttpResponse] object, used for sending back the response to the client (read-only).
  HttpResponse get response;

  ///The [HttpRequest] object of the given request (read-only).
  HttpRequest get httpRequest;

}

/**
 * A request whose body was not fully read yet
 */
abstract class UnparsedRequest extends Request {
  
  Future parseBody();
  
}

/**
 * The chain of the given request.
 *
 * A chain is composed of a target and 0 or more interceptors,
 * and it can be directly manipulated only by interceptors.
 */
abstract class Chain {

  /**
   * Get a [Future] that will complete when this Chain
   * has completed.
   */
  Future get done;
  
  ///The error object thrown by the target
  dynamic get error;
  
  /**
   * Call the next element of this chain (an interceptor or a target)
   *
   * The given [callback] will be executed when all following elements
   * in the chain are completed. The callback can return a [Future].
   */
  void next([callback()]);

  ///Interrupt this chain and closes the current request.
  void interrupt({int statusCode: HttpStatus.OK, Object response, String responseType});
  
  ///Returns true if this chain was interrupted
  bool get interrupted;

}

/**
 * User credentials from request
 * 
 */
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
  request.response.statusCode = statusCode;
  _notifyError(request.response, request.httpRequest.uri.path);
  chain.interrupt(statusCode: statusCode);
}

/**
 * Redirect the user to [url].
 *
 * [url] can be absolute, or relative to the url of the current request.
 */
void redirect(String url) {
  chain.interrupt(statusCode: HttpStatus.MOVED_TEMPORARILY);
  request.response.redirect(request.httpRequest.uri.resolve(url));
}

/**
 * Parse authorization header from request.
 * 
 */
Credentials parseAuthorizationHeader() {
  if (request.headers[HttpHeaders.AUTHORIZATION] != null) {
    String authorization = request.headers[HttpHeaders.AUTHORIZATION][0];
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
 * If authentication fails and [abortOnFail] is true, then [abort] will be 
 * called with the 401 status code. If authentication fails and [realm] is provided, 
 * a 'www-authenticate' header will be added to response.
 */
bool authenticateBasic(String username, String password, {String realm, bool abortOnFail: false}){
  bool r = false;
  var headers = request.headers;
  if (request.headers[HttpHeaders.AUTHORIZATION] != null) {
    String authorization = request.headers[HttpHeaders.AUTHORIZATION][0];
    List<String> tokens = authorization.split(" ");
    String auth = CryptoUtils.bytesToBase64(conv.UTF8.encode("$username:$password"));
    if ("Basic" == tokens[0] && auth == tokens[1]) {
      r = true;
    }
  }
  if (!r) {
    if (realm != null) {
      request.response.headers.add(HttpHeaders.WWW_AUTHENTICATE, 'Basic realm="$realm"');
    }
    if (abortOnFail) {
      abort(HttpStatus.UNAUTHORIZED);
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
 * Start the server.
 *
 * The [address] can be a [String] or an [InternetAddress]. The [staticDir] is an
 * absolute or relative path to static files, which defaults to the 'web' directory
 * of the project or build. If no static files will be handled by this server, the [staticDir]
 * can be setted to null.
 */
Future<HttpServer> start({address: _DEFAULT_ADDRESS, int port: _DEFAULT_PORT, 
                          String staticDir: _DEFAULT_STATIC_DIR,
                          List<String> indexFiles: _DEFAULT_INDEX_FILES,
                          bool followLinks: false, bool jailRoot: true}) {
  return new Future(() {
    
    setUp();

    if (staticDir != null) {
      String dir = Platform.script.resolve(staticDir).toFilePath();
      _logger.info("Setting up VirtualDirectory for ${dir} - followLinks: $followLinks - jailRoot: $jailRoot - index files: $indexFiles");
      _virtualDirectory = new VirtualDirectory(dir);
      _virtualDirectory..followLinks = followLinks
                       ..jailRoot = jailRoot
                       ..allowDirectoryListing = true;
      if (indexFiles != null && !indexFiles.isEmpty) {
        _virtualDirectory.directoryHandler = (dir, req) {
          int count = 0;
          for (String index in indexFiles) {
            var indexPath = path.join(dir.path, index);
            File f = new File(indexPath);
            if (f.existsSync() || count++ == indexFiles.length - 1) {
              _virtualDirectory.serveFile(f, req);
              break;
            }
          }
        };
      }
      _virtualDirectory.errorPageHandler = (req) {
        _logger.fine("Resource not found: ${req.uri}");
        _notifyError(req.response, req.uri.path);
        req.response.close();
      };

    }

    return runZoned(() {
      return HttpServer.bind(address, port).then((server) {
        server.listen((HttpRequest req) {

            _logger.fine("Received request for: ${req.uri}");
            _dispatchRequest(new _RequestImpl(req));

          });
  
        _logger.info("Running on $address:$port");
        return server;
      });
    }, onError: (e, s) {
      _logger.severe("Failed to handle request", e, s);
    });
  });
}

/**
 * Scan and initialize routes, interceptors and error handlers
 * 
 * If [libraries] is provided, then the scan process will be limited
 * to these libraries. This method is intended to be used in unit tests.
 */
void setUp([List<Symbol> libraries]) {
  try {
    _scanHandlers(libraries);
  } catch (e) {
    _handleError("Failed to configure handlers.", e);
    throw e;
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
Future<HttpResponse> dispatch(UnparsedRequest request) => _dispatchRequest(request);


/**
 * Allows to programmatically create routes, interceptors, error handlers
 * and parameter providers.
 * 
 * To access a [Manager] instance, you need to create and register a [RedstonePlugin].
 */
abstract class Manager {
  
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
   * [metadataType] is the annotation type that triggers this provider. 
   * [parameterProvider] is the function which will be invoked to create
   * the parameter's value. [handlerTypes] are the handler types that can use
   * this provider, and defaults to ROUTE.
   */
  void addParameterProvider(Type metadataType, ParamProvider parameterProvider, 
                            {List<String> handlerTypes: const [ROUTE]});
  
  /**
   * Create a new response processor.
   * 
   * [metadataType] is the annotation type that triggers this processor.
   * [processor] is the function which will be invoked to transform the returned
   * value. 
   */
  void addResponseProcessor(Type metadataType, ResponseProcessor processor);
  
}

/**
 * A plugin is a function which can dynamically add new features
 * to an application.
 */
typedef void RedstonePlugin(Manager manager);

/**
 * A route programmatically created by a plugin.
 */
typedef dynamic RouteHandler(Map<String, String> pathSegments, 
                             Injector injector, Request request);

/**
 * An interceptor or error handler, programmatically created by a plugin.
 */
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
