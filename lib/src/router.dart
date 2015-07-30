library redstone.src.router;

import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelfIo;
import 'package:route_hierarchical/url_template.dart';
import 'package:route_hierarchical/url_matcher.dart';
import 'package:stack_trace/stack_trace.dart' as st;

import 'server_context.dart';
import 'server_metadata.dart';
import 'request_context.dart';
import 'request.dart';
import 'request_parser.dart';
import 'response_writer.dart';
import 'dynamic_map.dart';
import 'logger.dart';
import 'bootstrap.dart';

const String serverSignature = "dart:io with Redstone.dart/Shelf";

/// An router is responsible for handling http requests.
class Router {
  ServerContext _serverCtx;
  bool showErrorPage;
  bool logSetUp;

  _TargetListBuilder _targetListBuilder = new _TargetListBuilder();
  _InterceptorListBuilder _interceptorListBuilder =
      new _InterceptorListBuilder();
  _ErrorHandlerMapBuilder _errorHandlerMapBuilder =
      new _ErrorHandlerMapBuilder();

  List<_Target> _targets;
  List<_Interceptor> _interceptors;
  Map<int, List<_ErrorHandler>> _errorHandlers;
  shelf.Handler _shelfHandler;
  shelf.Handler _forwardShelfHandler;

  Router(this._serverCtx, this.showErrorPage, this.logSetUp) {
    _loadHandlers();
    _targets = _targetListBuilder.build();
    _interceptors = _interceptorListBuilder.build();
    _errorHandlers = _errorHandlerMapBuilder.build();
    _buildShelfHandler();
  }

  Future handleRequest(HttpRequest request) {
    var requestParser = new RequestParser(request);
    return dispatchRequest(requestParser);
  }

  Future dispatchRequest(RequestParser request) async {
    var ctx = new RequestContext(request);
    return runZoned(
        () => shelfIo.handleRequest(request.httpRequest, _shelfHandler),
        zoneValues: {REQUEST_CONTEXT_KEY: ctx});
  }

  void _buildShelfHandler() {
    var pipeline = new shelf.Pipeline().addMiddleware(_middleware);
    var forwardPipeline =
        new shelf.Pipeline().addMiddleware(_forwardMiddleware);
    _serverCtx.shelfContext.middlewares
        .forEach((m) => pipeline = pipeline.addMiddleware(m));
    if (_serverCtx.shelfContext.handler != null) {
      var cascade = new shelf.Cascade()
          .add(_handler)
          .add(_serverCtx.shelfContext.handler);
      _shelfHandler = pipeline.addHandler(cascade.handler);
      _forwardShelfHandler = forwardPipeline.addHandler(cascade.handler);
    } else {
      _shelfHandler = pipeline.addHandler(_handler);
      _forwardShelfHandler = forwardPipeline.addHandler(_handler);
    }
  }

  shelf.Handler _middleware(shelf.Handler innerHandler) {
    return (shelf.Request req) {
      _ChainImpl chain = new _ChainImpl(_targets, _interceptors, _errorHandlers,
          _forwardShelfHandler, showErrorPage);
      currentContext.chain = chain;
      var completer = new Completer();

      st.Chain.capture(() async {
        try {
          shelf.Response resp = await innerHandler(req);
          if (resp.statusCode < 200 || resp.statusCode >= 300) {
            currentContext.response = resp;
            resp = await chain._handleError(null, null, resp.statusCode, true);
          }
          completer.complete(resp);
        } catch (e, stack) {
          if (e is shelf.HijackException) {
            completer.completeError(e);
            return;
          }
          completer.complete(chain._handleError(e, stack, 500, true));
        }
      }, onError: (e, st.Chain chain) {
        if (e is shelf.HijackException) {
          return;
        }
        redstoneLogger.severe("Failed to handle request for ${req.url}");
      });

      return completer.future.then((shelf.Response response) {
        redstoneLogger.fine(
            "Request for ${req.url} returned status ${response.statusCode}");
        return response.change(
            headers: const {HttpHeaders.SERVER: serverSignature});
      });
    };
  }

  shelf.Handler _forwardMiddleware(shelf.Handler innerHandler) {
    return (shelf.Request req) async {
      _ChainImpl chain = new _ChainImpl(
          _targets, const [], _errorHandlers, _forwardShelfHandler, false);
      var currentChain = currentContext.chain;
      var currentRequest = currentContext.request.shelfRequest;
      currentContext.chain = chain;
      try {
        shelf.Response resp = await innerHandler(req);
        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          currentContext.response = resp;
          resp = await chain._handleError();
        }
        return resp;
      } finally {
        currentContext.chain = currentChain;
        currentContext.request.shelfRequest = currentRequest;
      }
    };
  }

  Future<shelf.Response> _handler(shelf.Request request) async {
    currentContext.request.shelfRequest = request;
    return (currentContext.chain as _ChainImpl)._start();
  }

  void _loadHandlers(
      [String pathPrefix, List<int> chainIdxByLevel, LibraryMetadata lib]) {
    if (lib == null) {
      _serverCtx.serverMetadata.rootLibraries
          .forEach((l) => _loadHandlers(null, [], l));

      _loadDynamicHandlers();
      return;
    }

    var libPathPrefix = null;
    if (lib.conf != null) {
      if (lib.conf.urlPrefix != null) {
        libPathPrefix = lib.conf.urlPrefix;
      }
      if (lib.conf.chainIdx != null) {
        chainIdxByLevel.add(lib.conf.chainIdx);
      }
    }

    if (libPathPrefix != null) {
      pathPrefix = pathPrefix != null
          ? _joinUrl(pathPrefix, libPathPrefix)
          : libPathPrefix;
    }

    _getTargets(pathPrefix, lib);
    _getInterceptors(pathPrefix, chainIdxByLevel, lib);
    _getErrorHandlers(pathPrefix, lib);

    if (lib.dependencies.isNotEmpty) {
      lib.dependencies
          .forEach((l) => _loadHandlers(pathPrefix, chainIdxByLevel, l));
    }
  }

  void _loadDynamicHandlers() {
    _serverCtx.serverMetadata.routes.where((r) => r.library == null).forEach(
        (r) => _targetListBuilder.add("/", new UrlTemplate(r.conf.urlTemplate),
            r.conf.methods, _serverCtx.routeInvokers[r]));

    _interceptorListBuilder.add(_serverCtx.serverMetadata.interceptors
        .where((i) => i.library == null)
        .map((i) => new _Interceptor(new RegExp(i.conf.urlPattern),
            [i.conf.chainIdx], _serverCtx.interceptorInvokers[i])));

    _serverCtx.serverMetadata.errorHandlers
        .where((e) => e.library == null)
        .forEach((e) => _errorHandlerMapBuilder.add(e.conf.statusCode,
            new _ErrorHandler(e.conf.urlPattern != null
                ? new RegExp(e.conf.urlPattern)
                : null, _serverCtx.errorHandlerInvokers[e])));
  }

  void _getTargets(String pathPrefix, LibraryMetadata lib) {
    for (RouteMetadata route in lib.routes) {
      var urlTemplate = null;

      var url = null;
      if (pathPrefix != null) {
        url = _joinUrl(pathPrefix, route.conf.urlTemplate);
        urlTemplate = new UrlTemplate(url);
      } else {
        url = route.conf.urlTemplate;
        urlTemplate = new UrlTemplate(route.conf.urlTemplate);
      }

      if (logSetUp) {
        redstoneLogger.info(
            "Configured target for ${url} ${route.conf.methods}: ${route.name}");
      }
      _targetListBuilder.add(_getContextUrl(pathPrefix), urlTemplate,
          route.conf.methods, _serverCtx.routeInvokers[route]);
    }

    for (GroupMetadata group in lib.groups) {
      for (DefaultRouteMetadata route in group.defaultRoutes) {
        var url = null;
        var urlTemplate = null;

        if (pathPrefix != null) {
          url = _joinUrl(pathPrefix, group.conf.urlPrefix);
        } else {
          url = group.conf.urlPrefix;
        }

        String contextUrl = _getContextUrl(pathPrefix);

        if (route.conf.pathSuffix != null) {
          url += route.conf.pathSuffix;
        }

        urlTemplate = new UrlTemplate(url);
        if (logSetUp) {
          redstoneLogger.info(
              "Configured target for ${url} ${route.conf.methods}: ${route.name}"
              " (group: ${group.name})");
        }
        _targetListBuilder.add(contextUrl, urlTemplate, route.conf.methods,
            _serverCtx.routeInvokers[route]);
      }

      for (RouteMetadata route in group.routes) {
        var urlTemplate = null;

        var url = null;
        var contextUrl = null;
        if (pathPrefix != null) {
          contextUrl = _joinUrl(pathPrefix, group.conf.urlPrefix);
          url = _joinUrl(contextUrl, route.conf.urlTemplate);
          urlTemplate = new UrlTemplate(url);
        } else {
          contextUrl = group.conf.urlPrefix;
          url = _joinUrl(group.conf.urlPrefix, route.conf.urlTemplate);
          urlTemplate = new UrlTemplate(url);
        }

        if (logSetUp) {
          redstoneLogger.info(
              "Configured target for ${url} ${route.conf.methods}: ${route.name}"
              " (group: ${group.name})");
        }
        _targetListBuilder.add(_getContextUrl(contextUrl), urlTemplate,
            route.conf.methods, _serverCtx.routeInvokers[route]);
      }
    }
  }

  void _getInterceptors(
      String pathPrefix, List<int> chainIdxByLevel, LibraryMetadata lib) {
    var interceptors = lib.interceptors.map((i) {
      var url = _joinUrl(pathPrefix, i.conf.urlPattern);
      if (logSetUp) {
        redstoneLogger.info("Configured interceptor for $url : ${i.name}");
      }
      return new _Interceptor(new RegExp(url), []
        ..addAll(chainIdxByLevel)
        ..add(i.conf.chainIdx), _serverCtx.interceptorInvokers[i]);
    }).toList();

    lib.groups.forEach((g) {
      var pattern = _joinUrl(pathPrefix, g.conf.urlPrefix);
      interceptors.addAll(g.interceptors.map((i) {
        var url = _joinUrl(pattern, i.conf.urlPattern);
        if (logSetUp) {
          redstoneLogger.info("Configured interceptor for $url : ${i.name}"
              " (group: ${g.name})");
        }
        return new _Interceptor(new RegExp(url), []
          ..addAll(chainIdxByLevel)
          ..add(i.conf.chainIdx), _serverCtx.interceptorInvokers[i]);
      }));
    });

    _interceptorListBuilder.add(interceptors);
  }

  void _getErrorHandlers(String pathPrefix, LibraryMetadata lib) {
    lib.errorHandlers.forEach((e) {
      var handlerPattern = pathPrefix != null && e.conf.urlPattern == null
          ? r"/.*"
          : e.conf.urlPattern;
      var pattern = _joinUrl(pathPrefix, handlerPattern);

      var urlInfo = pattern != null ? " - $pattern" : "";
      if (logSetUp) {
        redstoneLogger.info(
            "Configured error handler for status ${e.conf.statusCode} $urlInfo :"
            "${e.name}");
      }

      _errorHandlerMapBuilder.add(e.conf.statusCode, new _ErrorHandler(
          pattern != null ? new RegExp(pattern) : null,
          _serverCtx.errorHandlerInvokers[e]));
    });

    lib.groups.forEach((g) {
      var pattern = _joinUrl(pathPrefix, g.conf.urlPrefix);
      g.errorHandlers.forEach((e) {
        var handlerPattern =
            e.conf.urlPattern == null ? r"/.*" : e.conf.urlPattern;
        handlerPattern = _joinUrl(pattern, handlerPattern);
        if (logSetUp) {
          redstoneLogger.info(
              "Configured error handler for status ${e.conf.statusCode} "
              "$handlerPattern : ${e.name} (group: ${g.name})");
        }
        _errorHandlerMapBuilder.add(e.conf.statusCode, new _ErrorHandler(
            new RegExp(handlerPattern), _serverCtx.errorHandlerInvokers[e]));
      });
    });
  }

  String _getContextUrl(String prefix) {
    if (prefix == null) {
      return "/";
    }
    if (prefix.startsWith("/")) {
      return prefix.substring(1);
    }
    return prefix;
  }
}

class _ChainImpl implements Chain {
  final List<_Target> _targets;
  final List<_Interceptor> _interceptors;
  final Map<int, List<_ErrorHandler>> _errorHandlers;
  final shelf.Handler _forwardShelfHandler;
  final bool showErrorPage;

  Iterator<_Interceptor> _reqInterceptors;
  _Target _reqTarget;

  Object _error;
  Object _stackTrace;

  bool _errorHandlerExecuted = false;

  _ChainImpl(this._targets, this._interceptors, this._errorHandlers,
      this._forwardShelfHandler, this.showErrorPage);

  @override
  dynamic get error => _error;

  @override
  dynamic get stackTrace => _stackTrace;

  @override
  Future<shelf.Response> createResponse(int statusCode,
      {Object responseValue, String responseType}) async {
    var resp = await writeResponse(null, responseValue,
        statusCode: statusCode, responseType: responseType);
    return resp;
  }

  @override
  Future<shelf.Response> next() async {
    if (_reqInterceptors.moveNext()) {
      try {
        var resp =
            await _reqInterceptors.current.interceptor(currentContext.request);
        if (resp is shelf.Response) {
          currentContext.response = resp;
        }
      } catch (err, stack) {
        if (err is shelf.HijackException) {
          rethrow;
        }
        await _handleError(err, stack);
      }
      return currentContext.response;
    }

    if (_reqTarget != null) {
      return currentContext.response;
    }

    _findTarget();
    if (_reqTarget == null) {
      currentContext.response = new shelf.Response.notFound(null);
    } else {
      try {
        var shelfReq = currentContext.request.shelfRequest;
        if (shelfReq.handlerPath != _reqTarget.contextUrl) {
          shelfReq = shelfReq.change(path: _reqTarget.contextUrl);
          currentContext.request.shelfRequest = shelfReq;
        }
        var invoker = _reqTarget.routes[currentContext.request.method];
        var resp;
        if (invoker != null) {
          resp = await invoker(currentContext.request);
        } else {
          resp = new shelf.Response(HttpStatus.METHOD_NOT_ALLOWED);
        }
        currentContext.response = resp;
      } catch (err, stack) {
        if (err is shelf.HijackException) {
          rethrow;
        }
        await _handleError(err, stack);
      }
    }

    return currentContext.response;
  }

  @override
  Future<shelf.Response> abort(int statusCode) async {
    await _handleError(null, null, statusCode);
    return currentContext.response;
  }

  @override
  shelf.Response redirect(String url) {
    var resp =
        new shelf.Response.found(currentContext.request.url.resolve(url));
    currentContext.response = resp;
    return resp;
  }

  @override
  Future<shelf.Response> forward(String url,
      {Map<String, String> headers}) async {
    var req = currentContext.request;
    var newUrl = url.startsWith('/') ? req.requestedUri.resolve(url) : Uri.parse(_joinUrl(req.requestedUri.toString(), url));
    var shelfReqCtx = new Map.from(req.attributes);
    var newReq = new shelf.Request("GET", newUrl
      ,headers: headers, context: shelfReqCtx);

    return _forwardShelfHandler(newReq);
  }

  Future<shelf.Response> _start() {
    _findReqInterceptors();
    return next();
  }

  Future<shelf.Response> _handleError([Object err, StackTrace stack,
      int statusCode = 500, bool generatePage = false]) async {
    statusCode = statusCode != null ? statusCode : 500;

    if (stack != null) {
      stack = new st.Chain.forTrace(stack).terse;
    }

    if (err != null && statusCode == 500) {
      redstoneLogger.severe("Internal server error.", err, stack);
    }

    if (!_errorHandlerExecuted) {
      _errorHandlerExecuted = true;
      _error = err;
      _stackTrace = stack;
      currentContext.lastStackTrace = stack;
      shelf.Response resp = currentContext.response;
      if (err != null || resp.statusCode != statusCode) {
        resp = await writeResponse(null, err, statusCode: statusCode);
      }
      currentContext.response = resp;
      statusCode = resp.statusCode;

      _ErrorHandler errorHandler = _findErrorHandler();
      if (errorHandler != null) {
        resp = await errorHandler.errorHandler(currentContext.request);
        if (resp is shelf.Response) {
          currentContext.response = resp;
        }
      }
    }

    if (generatePage) {
      if (showErrorPage) {
        if (err == null) {
          err = _error;
        }
        if (stack == null) {
          stack = currentContext.lastStackTrace;
        }
        shelf.Response resp = await writeErrorPage(
            currentContext.request.shelfRequest.requestedUri.path, err, stack,
            statusCode);
        currentContext.response = resp;
      }
    }

    return currentContext.response;
  }

  void _findReqInterceptors() {
    String reqPath = currentContext.request.shelfRequest.requestedUri.path;
    _reqInterceptors = _interceptors.where((i) {
      var match = i.urlRegex.firstMatch(reqPath);
      if (match != null) {
        return match[0] == reqPath;
      }
      return false;
    }).iterator;
  }

  void _findTarget() {
    for (_Target target in _targets) {
      UrlMatch match =
          target.template.match(currentContext.request.shelfRequest.requestedUri.path);
      if (match != null && match.tail.isEmpty) {
        var urlParameters = {};
        match.parameters.forEach((String key, String value) {
          if (key.endsWith("*")) {
            key = key.substring(0, key.length - 1);
          }
          urlParameters[key] = value;
        });
        currentContext.request.urlParameters = new DynamicMap(urlParameters);
        _reqTarget = target;
        return;
      }
    }
  }

  _ErrorHandler _findErrorHandler() {
    var statusCode = currentContext.response.statusCode;
    var reqPath = currentContext.request.shelfRequest.requestedUri.path;
    List<_ErrorHandler> handlers = _errorHandlers[statusCode];
    if (handlers == null) {
      return null;
    }

    return handlers.firstWhere((e) {
      if (e.urlRegex == null) {
        return true;
      }
      var match = e.urlRegex.firstMatch(reqPath);
      return match != null ? match[0] == reqPath : false;
    }, orElse: () => null);
  }
}

class _TargetListBuilder {
  final List<_Target> targets = [];
  final Map<String, _Target> mapTargets = {};

  void add(String contextUrl, UrlTemplate url, List<String> methods,
      RouteInvoker invoker) {
    var key = url.toString();
    var target = mapTargets[key];
    if (target == null) {
      target = new _Target(contextUrl, url);
      mapTargets[key] = target;
    }

    for (String method in methods) {
      target.routes[method] = invoker;
    }

    targets.add(target);
  }

  List<_Target> build() {
    targets.sort((t1, t2) => t1.template.compareTo(t2.template));
    return targets.toList(growable: false);
  }
}

class _Target {
  final String contextUrl;
  final UrlTemplate template;
  final Map<String, RouteInvoker> routes = {};

  _Target(this.contextUrl, this.template);
}

class _InterceptorListBuilder {
  final List<_Interceptor> interceptors = [];

  void add(Iterable<_Interceptor> interceptors) =>
      this.interceptors.addAll(interceptors);

  List<_Interceptor> build() {
    interceptors.sort((i1, i2) {
      var idxs1 = i1.chainIdxByLevel;
      var idxs2 = i2.chainIdxByLevel;
      for (int i = 0; i < max(idxs1.length, idxs2.length); i++) {
        int l1 = i < idxs1.length ? idxs1[i] : null;
        int l2 = i < idxs2.length ? idxs2[i] : null;
        if (l1 != null && l2 == null) {
          return -1;
        } else if (l1 == null) {
          return l2 == null ? 0 : 1;
        } else if (l1 == l2) {
          continue;
        } else {
          return l1 - l2;
        }
      }
      return 0;
    });

    return interceptors.toList(growable: false);
  }
}

class _Interceptor {
  final RegExp urlRegex;
  final List<int> chainIdxByLevel;
  final InterceptorInvoker interceptor;

  _Interceptor(this.urlRegex, this.chainIdxByLevel, this.interceptor);
}

class _ErrorHandlerMapBuilder {
  final Map<int, List<_ErrorHandler>> errorHandlers = {};

  void add(int status, _ErrorHandler errorHandler) {
    var errorHandlerList = errorHandlers[status];
    if (errorHandlerList == null) {
      errorHandlerList = [];
      errorHandlers[status] = errorHandlerList;
    }

    errorHandlerList.add(errorHandler);
  }

  Map<int, List<_ErrorHandler>> build() {
    var map = {};
    errorHandlers.forEach((status, errorHandlerList) {
      map[status] = errorHandlerList
        ..sort((e1, e2) {
          if (e1.urlRegex == null) {
            return e2.urlRegex == null ? 0 : 1;
          } else if (e2.urlRegex == null) {
            return -1;
          } else {
            var length1 = e1.urlRegex.pattern.split(r'/').length;
            var length2 = e2.urlRegex.pattern.split(r'/').length;
            return length2 - length1;
          }
        })
        ..toList(growable: false);
    });
    return map;
  }
}

class _ErrorHandler {
  final RegExp urlRegex;
  final ErrorHandlerInvoker errorHandler;

  _ErrorHandler(this.urlRegex, this.errorHandler);
}

String _joinUrl(String prefix, String url) {
  if (prefix == null) {
    return url;
  }
  if (url == null) {
    return prefix;
  }
  if (prefix.endsWith("/")) {
    prefix = prefix.substring(0, prefix.length - 1);
  }

  return url.startsWith("/") ? "$prefix$url" : "$prefix/$url";
}
