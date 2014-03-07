library bloodless_server;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'dart:convert' as conv;

import 'package:http_server/http_server.dart';
import 'package:mime/mime.dart';
import 'package:route_hierarchical/url_matcher.dart';
import 'package:route_hierarchical/url_template.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

part 'package:bloodless/src/metadata.dart';
part 'package:bloodless/src/logger.dart';
part 'package:bloodless/src/exception.dart';
part 'package:bloodless/src/server_impl.dart';

const String GET = "GET";
const String POST = "POST";
const String PUT = "PUT";
const String DELETE = "DELETE";

const String JSON = "json";
const String FORM = "form";
const String TEXT = "text";

const String _DEFAULT_ADDRESS = "0.0.0.0";
const int _DEFAULT_PORT = 8080;
const String _DEFAULT_STATIC_DIR = "../web";
const List<String> _DEFAULT_INDEX_FILES = const ["index.html"];

/**
 * The request's information and content.
 *
 * This class is just a wrapper to the [HttpRequestBody]
 * and [HttpRequest] objects.
 */
class Request {

  HttpRequestBody _reqBody;
  Map<String, String> _queryParams;

  Request(HttpRequestBody this._reqBody,
          Map<String, String> this._queryParams);

  ///The method, such as 'GET' or 'POST', for the request (read-only).
  String get method => _reqBody.request.method;

  ///The query parameters associated with the request
  Map<String, String> get queryParams => _queryParams;

  ///The body type, such as 'application/json' or 'text/plain'
  String get bodyType => _reqBody.type;

  /**
   * The request's body.
   *
   * [body] can be a [Map], [List] or [String]. See [HttpRequestBody]
   * for more information.
   */ 
  dynamic get body => _reqBody.body;

  ///The headers of the request
  HttpHeaders get headers => _reqBody.request.headers;

  ///The session for the given request (read-only).
  HttpSession get session => _reqBody.request.session;

  ///The [HttpResponse] object, used for sending back the response to the client (read-only).
  HttpResponse get response => _reqBody.request.response;

  ///The [HttpRequest] object of the given request (read-only).
  HttpRequest get httpRequest => _reqBody.request;

}

/**
 * The chain of the given request.
 *
 * A chain is composed of a target and 0 or more interceptors,
 * and it can be directly manipulated only by interceptors.
 */
abstract class Chain {

  /**
   * Call the next element of this chain (an interceptor or a target)
   *
   * The returned [Future] will be completed when all following elements
   * in the chain are completed. It completes with [true] if the target
   * was found and executed, and with [false] if the request was fowarded
   * to the VirtualDirectory.
   */
  Future<bool> next();

  ///Interrupt this chain and close the current request.
  void interrupt(int statusCode, {Object response, String responseType});

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
 * Since each request run in it's own [Zone], it's completely safe
 * to access this object at any time, even in async callbacks.
 */
Chain get chain => Zone.current[#chain];

/**
 * Abort the current request.
 *
 * If there is a ErrorHandler registered to [statusCode], it
 * will be invked. Otherwise, the default ErrorHandler will be invoked.
 */
void abort(int statusCode) {
  (chain as _ChainImpl)._interrupted = true;
  _notifyError(request.response, request.httpRequest.uri.path);
}

/**
 * Redirect the user to [url].
 *
 * [url] can be absolute, or relative to the url of the current request.
 */
void redirect(String url) {
  (chain as _ChainImpl)._interrupted = true;
  request.response.redirect(request.httpRequest.uri.resolve(url));
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
                          List<String> indexFiles: _DEFAULT_INDEX_FILES}) {
  return new Future(() {
    
    try {
      _scanHandlers();
    } catch (e) {
      _handleError("Failed to configure handlers.", e);
      throw e;
    }

    if (staticDir != null) {
      String dir = Platform.script.resolve(staticDir).toFilePath();
      _logger.info("Setting up VirtualDirectory for ${dir} - index files: $indexFiles");
      _virtualDirectory = new VirtualDirectory(dir);
      _virtualDirectory..followLinks = true
                       ..jailRoot = false
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
      };

    }

    return HttpServer.bind(address, port).then((server) {
      server.transform(new HttpBodyHandler())
          .listen((HttpRequestBody req) {

            _logger.fine("Received request for: ${req.request.uri}");
            _handleRequest(req);

          });

      _logger.info("Running on $address:$port");
      return server;
    });
  });
}