part of redstone_server;

typedef Future _RequestHandler(UrlMatch match, Request request);
typedef void _RunInterceptor();
typedef Future _HandleError();
typedef dynamic _ConvertFunction(String value, dynamic defaultValue);

class _RequestState {

  UrlMatch urlMatch;
  bool chainInitialized = false;
  bool errorHandlerInvoked = false;
  bool requestAborted = false;
  shelf.Response response;

}

class _RequestImpl extends HttpRequestParser implements UnparsedRequest {

  HttpRequest httpRequest;
  shelf.Request _shelfRequest;

  QueryMap _headers = null;
  QueryMap _queryParams = null;

  shelf.Request get shelfRequest => _shelfRequest;

  set shelfRequest(shelf.Request shelfRequest) {
    _shelfRequest = shelfRequest;
    _headers = new QueryMap(shelfRequest.headers);
    _queryParams = new QueryMap(shelfRequest.url.queryParameters);
  }

  final QueryMap _attributes = new QueryMap({});

  _RequestImpl(this.httpRequest);

  Uri get requestedUri => _shelfRequest.requestedUri;

  Uri get url => _shelfRequest.url;

  Map<String, String> get headers => _headers;

  Map get attributes => _attributes;

  String get method => _shelfRequest.method;

  Map<String, String> get queryParams => _queryParams;

  HttpSession get session => httpRequest.session;

  void parseBodyType() => parseHttpRequestBodyType(headers);

  Future parseBody() {
    if (bodyHasBeenParsed() == false) {
      return parseHttpRequestBody(_shelfRequest.read());
    } else {
      return parseHttpRequestBody(null);
    }

  }

}

final shelf.Handler _redstoneHandler = (shelf.Request req) {
  return Zone.current[#chain]._handleShelfRequest(req);
};

final shelf.Middleware _redstoneMiddleware = (shelf.Handler handler) {
  return (shelf.Request shelfRequest) {
    var completer = new Completer();
    runZoned(() {
      var resp = handler(shelfRequest);
      if (resp is Future) {
        resp.then((r) {
          if (!completer.isCompleted) {
            _commitResponse(r, completer);
          }
        });
      } else {
        if (!completer.isCompleted) {
          _commitResponse(resp, completer);
        }
      }
    }, onError: (e, s) {
      if (!completer.isCompleted) {
        _handleError("Failed to handle request.", e,
           stack: s, req: request)
             .then((_) {
               if (!completer.isCompleted) {
                _commitResponse(response, completer);
               }
             })
             .catchError((e) => completer.completeError(e));
      }
    });
    return completer.future;
  };
};

shelf.Pipeline _buildShelfPipeline() => 
    new shelf.Pipeline().addMiddleware(_redstoneMiddleware);

void _buildMainHandler() {
  if (_shelfPipeline != null) {
    _mainHandler = _shelfPipeline.addHandler(_redstoneHandler);
  } else {
    _mainHandler = _buildShelfPipeline()
                        .addHandler(_redstoneHandler);
  }
}

void _commitResponse(shelf.Response resp, Completer completer) {
  if (!resp.headers.containsKey(HttpHeaders.SERVER)) {
    resp = resp.change(headers: const {HttpHeaders.SERVER: "dart:io with Redstone.dart/Shelf"});
  }
  completer.complete(resp);
}

List<_Interceptor> _getInterceptors(Uri uri) {
  String path = uri.path;
  return _interceptors.where((i) {
    var match = i.urlPattern.firstMatch(path);
    if (match != null) {
      return match[0] == path;
    }
    return false;
  }).toList();
}

_Target _getTarget(Uri uri, _RequestState state) {
  for (var target in _targets) {
    UrlMatch match = target.match(uri);
    if (match != null) {
      state.urlMatch = match;
      return target;
    }
  }
  return null;
}

Future<HttpResponse> _dispatchRequest(UnparsedRequest req) {

  var completer = new Completer();
  var state = new _RequestState();

  Chain chain;
  try {

    List<_Interceptor> interceptors = _getInterceptors(req.httpRequest.uri);
    _Target target = _getTarget(req.httpRequest.uri, state);

    chain = new _ChainImpl(interceptors, target, req);
  } catch(e, s) {
    _handleError("Failed to handle request.", e, stack: s).then((_) =>
        completer.completeError(e, s));
    return completer.future;
  }

  _process(req, state, chain, completer);

  return completer.future;
}

void _process(UnparsedRequest req, _RequestState state,
              _ChainImpl chain, Completer completer) {
  runZoned(() {

    try {
      shelf_io.handleRequest(req.httpRequest, _mainHandler).then((_) {
        _logger.finer("Closed request for: ${request.url}");
        completer.complete(req.httpRequest.response);
      });
    } catch (e) {
      //Shelf is throwing synchronous errors for invalid requests
      _handleError("Invalid request!", e, logLevel: Level.FINE);
      //avoid resource leak
      try {
        req.httpRequest.response.close();
      } catch(e) {}
    }

  }, zoneValues: {
    #request: req,
    #chain: chain,
    #state: state
  }, onError: (e, s) {
    _handleError("Uncaught error. Please, report this at https://github.com/luizmineo/redstone.dart", e, stack: s);
    //avoid resource leak
    try {
      req.httpRequest.response.close();
    } catch(e) {}
  });
}

Future _handleError(String message, Object error, {StackTrace stack, Request req,
                  int statusCode, Level logLevel: Level.SEVERE,
                  bool printErrorPage: true}) {

  if (error is shelf.HijackException) {
    return new Future.error(error);
  }

  _logger.log(logLevel, message, error, stack);

  if (req == null) {
    return new Future.value();
  }

  return new Future.sync(() {

    if (statusCode == null) {
      if (error is RequestException) {
        statusCode = error.statusCode;
      } else {
        statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
      }
    }

    _RequestState state = Zone.current[#state];
    if (!state.errorHandlerInvoked) {
      state.errorHandlerInvoked = true;
      return _notifyError(statusCode, req.url.path,
          error: error, stack: stack, printErrorPage: printErrorPage);
    }

  });
}

Future _verifyRequest(_Target target, UnparsedRequest req) {

  return new Future.sync(() {

    if (target == null) {
      return null;
    }

    //verify method
    if (!target.route.methods.contains(req.method)) {
      throw new RequestException(target.handlerName,
        "${req.method} method not allowed for this target",
        HttpStatus.METHOD_NOT_ALLOWED);
    }

    //verify multipart
    if (req.isMultipart && !target.route.allowMultipartRequest) {
      throw new RequestException(target.handlerName,
        "multipart requests are not allowed for this target");
    }

    //verify body type
    if (!target.bodyTypes.contains("*") && !target.bodyTypes.contains(req.bodyType)) {
      throw new RequestException(target.handlerName,
        "${req.bodyType} data not supported for this target");
    }

  });

}

Future _runTarget(_Target target, UnparsedRequest req, shelf.Handler handler) {

  return _verifyRequest(target, req).then((_) {

    Future f = null;
    if (target != null) {
      f = req.parseBody().then((_) => target.handleRequest(req, Zone.current[#state].urlMatch));
    }

    if (f == null) {
      if (handler != null) {
        var r = handler(req.shelfRequest);
        f = new Future.value(r).then((resp) {
          response = resp;
          if (response.statusCode < 200 || response.statusCode >= 300) {
            return _notifyError(response.statusCode, req.url.path);
          }
        });
      } else {
        _logger.fine("resource not found: ${req.url}");

        f = _notifyError(HttpStatus.NOT_FOUND, req.url.path);
      }
    }

    return f;

  });

}

class _ChainImpl implements Chain {

  List<_Interceptor> _interceptors;
  _Target _target;

  _Interceptor _currentInterceptor;
  UnparsedRequest _request;

  bool _bodyTypeParsed = false;
  bool _targetInvoked = false;
  bool _interrupted = false;

  final Completer _completer = new Completer();

  List _callbacks = [];

  _ChainImpl(this._interceptors, this._target, this._request);

  Future _handleShelfRequest(shelf.Request req) {
    _request.shelfRequest = req;
    _request.attributes.addAll(req.context);
    Zone.current[#state].chainInitialized = true;
    next();
    return _completer.future;
  }

  Future _invokeCallbacks() {
    var callbacks = _callbacks.reversed;
    _callbacks = [];
    return Future.forEach(callbacks, (c) {
      var v = c();
      if (v != null) {
        if (v is Future) {
          return v.then((r) {
            if (r is shelf.Response) {
              response = r;
            }
          });
        }
        if (v is shelf.Response) {
          response = v;
        }
      }
      return new Future.value();
    }).then((_) => _completer.complete(response));
  }

  dynamic error;

  void next([callback()]) {
    new Future.sync(() {
      if (_interrupted) {
        var name = _currentInterceptor != null ? _currentInterceptor.interceptorName : null;
        throw new ChainException(request.url.path,
                                 "invalid state: chain already interrupted",
                                 interceptorName: name);
      }
      if (_interceptors.isEmpty && _targetInvoked) {
        throw new ChainException(request.url.path, "chain.next() must be called from an interceptor.");
      }

      if (!_bodyTypeParsed) {
        response = new shelf.Response.ok(null);
        _request.parseBodyType();
        _bodyTypeParsed = true;
      }

      if (callback != null) {
        _callbacks.add(callback);
      }

      if (_interceptors.isNotEmpty) {
        _currentInterceptor = _interceptors.removeAt(0);
        new Future(() {
          if (_currentInterceptor.parseRequestBody) {
            return _request.parseBody().then((_) =>
                _currentInterceptor.runInterceptor()).catchError((e, s) {
              if (!_interrupted) {
                error = e;
                var name = _currentInterceptor.interceptorName;
                return _handleError("Failed to execute interceptor $name", e,
                    stack: s, req: request).then((_) => _invokeCallbacks());
              }
            });
          } else {
            new Future.sync(() => _currentInterceptor.runInterceptor()).catchError((e, s) {
              if (!_interrupted) {
                error = e;
                var name = _currentInterceptor.interceptorName;
                return _handleError("Failed to execute interceptor $name", e,
                    stack: s, req: request).then((_) => _invokeCallbacks());
              }
            });
          }
        });
      } else {
        _currentInterceptor = null;
        _targetInvoked = true;
        new Future(() {
          _runTarget(_target, request, _defaultHandler).then((_) {
            if (!_interrupted && !Zone.current[#state].requestAborted) {
              return _invokeCallbacks();
            }
          }).catchError((e, s) {
            if (!_interrupted) {
              error = e;
              var level = e is RequestException ? Level.FINE : Level.SEVERE;
              var name = _target != null ? _target.handlerName : "shelf handler";
              return _handleError("Failed to execute ${name}", e,
                  stack: s, logLevel: level,
                  req: request).then((_) => _invokeCallbacks());
            }
          });
        });
      }

    });
  }

  void interrupt({int statusCode, Object responseValue, String responseType}) {
    if (_interrupted) {
      var name = _currentInterceptor != null ? _currentInterceptor.interceptorName : null;
      throw new ChainException(request.url.path,
                               "invalid state: chain already interrupted",
                               interceptorName: name);
    }

    _interrupted = true;

    Future f = new Future.value();
    if (statusCode != null || responseValue != null) {
      f = _writeResponse(responseValue, responseType, statusCode: statusCode);
    }
    f.then((_) => _invokeCallbacks());
  }

  bool get interrupted => _interrupted;

}

Future _writeResponse(respValue, String responseType, {int statusCode: 200,
  bool abortIfChainInterrupted: false, List<_ResponseHandler> processors}) {

  Completer completer = new Completer();

  if (respValue != null && respValue is ErrorResponse) {
    statusCode = respValue.statusCode;
    respValue = respValue.error;
  }

  if (abortIfChainInterrupted && chain.interrupted) {

    completer.complete();

  } else if (respValue == null) {

    if (processors != null && processors.isNotEmpty) {
      respValue = processors.fold(respValue, (v, p) =>
          p.processor(p.metadata, p.handlerName, v, _injector));
      _writeResponse(respValue, responseType,
          statusCode: statusCode,
          abortIfChainInterrupted: abortIfChainInterrupted).then((_) =>
              completer.complete());
    } else {

      response = new shelf.Response(statusCode);
      completer.complete();

    }

  } else if (respValue is Future) {

    respValue.then((fValue) {
      if (fValue is ErrorResponse) {
        throw fValue;
      }
      return _writeResponse(fValue, responseType,
          statusCode: statusCode,
          processors: processors,
          abortIfChainInterrupted: abortIfChainInterrupted);
    }).then((_) {
      completer.complete();
    }).catchError((e, s) {
      var f = _writeResponse(e, responseType,
                statusCode: statusCode,
                processors: processors,
                abortIfChainInterrupted: abortIfChainInterrupted);
      f.then((_) => completer.completeError(e, s));
    }, test: (e) => e is ErrorResponse)
    .catchError((e, s) {
      completer.completeError(e, s);
    });

  } else if (processors != null && !processors.isEmpty) {

    respValue = processors.fold(respValue, (v, p) =>
        p.processor(p.metadata, p.handlerName, v, _injector));
    _writeResponse(respValue, responseType,
        statusCode: statusCode,
        abortIfChainInterrupted: abortIfChainInterrupted).then((_) =>
            completer.complete());

  } else if (respValue is Map || respValue is List) {

    respValue = conv.JSON.encode(respValue);
    if (responseType == null) {
      responseType = "application/json";
    }
    response = new shelf.Response(statusCode, body: respValue, headers: {
      "content-type": responseType
    }, encoding: conv.UTF8);

    completer.complete();

  } else if (respValue is File) {

    File f = respValue as File;
    if (responseType == null) {
      String contentType = lookupMimeType(f.path);
      responseType = contentType;
    }
    response = new shelf.Response(statusCode, body: f.openRead(), headers: {
      "content-type": responseType
    });

    completer.complete();

  } else if (respValue is shelf.Response) {
    response = respValue;

    completer.complete();

  } else {

    if (responseType == null) {
      responseType = "text/plain";
    }
    response = new shelf.Response(statusCode, body: respValue.toString(), headers: {
      "content-type": responseType
    });

    completer.complete();

  }

  return completer.future;

}

_ErrorHandler _findErrorHandler(int statusCode, String path) {
  List<_ErrorHandler> handlers = _errorHandlers[statusCode];
  if (handlers == null) {
    return null;
  }

  return handlers.firstWhere((e) {
    if (e.urlPattern == null) {
      return true;
    }
    
    String intPath = path;
    
    if(!path.startsWith('/')) intPath = "/$path";
   
    var match = e.urlPattern.firstMatch(intPath);
    
    return match != null ? match[0] == intPath : false;
  }, orElse: () => null);
}

Future _notifyError(int statusCode, String resource,
                                   {Object error,
                                    StackTrace stack,
                                    bool printErrorPage: true}) {

  return new Future.sync(() {
    _ErrorHandler handler = _findErrorHandler(statusCode, request.url.path);
    if (handler != null) {
      return handler.errorHandler();
    } else if (printErrorPage) {
      _writeErrorPage(statusCode, resource, error, stack);
    }
  });
}

void _writeErrorPage(int statusCode, String resource, [Object error, StackTrace stack]) {

  String description = _getStatusDescription(statusCode);

  String formattedStack = null;
  if (stack != null) {
    formattedStack = Trace.format(stack);
  }

  String errorTemplate =
'''<!DOCTYPE>
<html>
<head>
  <title>Redstone Server - ${description != null ? description : statusCode}</title>
  <style>
    body, html {
      margin: 0px;
      padding: 0px;
      border: 0px;
    }
    .header {
      height:100px;
      background-color: rgba(204, 49, 0, 0.94);
      color:#F8F8F8;
      overflow: hidden;
    }
    .header p {
      font-family:Helvetica,Arial;
      font-size:36px;
      font-weight:bold;
      padding-left:10px;
      line-height: 30px;
    }
    .footer {
      margin-top:50px;
      padding-left:10px;
      height:20px;
      font-family:Helvetica,Arial;
      font-size:12px;
      color:#5E5E5E;
    }
    .content {
      font-family:Helvetica,Arial;
      font-size:18px;
      padding:10px;
    }
    .info {
      border: 1px solid #C3C3C3;
      margin-top: 10px;
      padding-left:10px;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div class="header" style="">
    <p>$statusCode ${description != null ? " - " + description : ""}</p>
  </div>
  <div class="content">
    <p><b>Resource: </b> $resource</p>

    <div class="info" style="display:${error != null ? "block" : "none"}">
      <pre>${error}${formattedStack != null ? "\n\n" + formattedStack : ""}</pre>
    </div>
  </div>
  <div class="footer">Redstone Server - 2015 - Luiz Mineo</div>
</body>
</html>''';

  response = new shelf.Response(statusCode, body: errorTemplate, headers: {
    "content-type": "text/html"
  }, encoding: conv.UTF8);

}

String _getStatusDescription(int statusCode) {

  switch (statusCode) {
    case HttpStatus.BAD_REQUEST: return "BAD REQUEST";
    case HttpStatus.NOT_FOUND: return "NOT FOUND";
    case HttpStatus.METHOD_NOT_ALLOWED: return "METHOD NOT ALLOWED";
    case HttpStatus.INTERNAL_SERVER_ERROR: return "INTERNAL SERVER ERROR";
    default: return null;
  }

}