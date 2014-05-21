part of redstone_server;

typedef Future _RequestHandler(UrlMatch match, Request request);
typedef void _RunInterceptor();
typedef Future _HandleError();
typedef dynamic _ConvertFunction(String value, dynamic defaultValue);

class _RequestState {
  
  bool errorHandlerInvoked = false;
  bool requestAborted = false;
  shelf.Response response;
  
}

class _RequestImpl extends ShelfTransformer with HttpRequestParser implements UnparsedRequest {

  HttpRequest _httpRequest;
  shelf.Request shelfRequest;
  
  final Map _attributes = {};
  
  _RequestImpl(this._httpRequest) {
    shelfRequest = buildShelfRequest(_httpRequest);
  }
  
  Uri get requestedUri => shelfRequest.requestedUri;
  
  Uri get url => shelfRequest.url;

  Map<String, String> get headers => shelfRequest.headers;

  Map get attributes => _attributes;
  
  String get method => shelfRequest.method;

  Map<String, String> get queryParams => shelfRequest.url.queryParameters;

  HttpSession get session => _httpRequest.session;
  
  void parseBodyType() => parseHttpRequestBodyType(headers);
  
  Future parseBody() => parseHttpRequestBody(shelfRequest.read());
  
}

List<_Interceptor> _getInterceptors(Uri uri) {
  String path = uri.path;
  return new List.from(_interceptors.where((i) {
    var match = i.urlPattern.firstMatch(path);
    if (match != null) {
      return match[0] == path;
    }
    return false;
  }));
}

_Target _getTarget(Uri uri) {
  for (var target in _targets) {
    if (target.match(uri)) {
      return target;
    }
  }
  return null;
}

Future<shelf.Response> _dispatchRequest(UnparsedRequest req) {
  
  var completer = new Completer();
  
  Chain chain;
  try {
    
    List<_Interceptor> interceptors = _getInterceptors(req.url);
    _Target target = _getTarget(req.url);

    chain = new _ChainImpl(interceptors, target, req, _initHandler, _finalHandler);
  } catch(e, s) {
    _handleError("Failed to handle request.", e, stack: s).then((_) =>
        completer.completeError(e, s));
    return completer.future;
  }
    
  _process(req, chain, completer);
    
  return completer.future;
}

Future _writeHttpResponse(shelf.Response response, HttpResponse httpResponse) {
  return new Future.sync(() {
    httpResponse.statusCode = response.statusCode;

    response.headers.forEach((header, value) {
      if (value == null) return;
      httpResponse.headers.set(header, value);
    });

    if (response.headers[HttpHeaders.SERVER] == null) {
      var value = httpResponse.headers.value(HttpHeaders.SERVER);
      httpResponse.headers.set(HttpHeaders.SERVER, '$value with Shelf');
    }
    return httpResponse.addStream(response.read())
        .then((_) => httpResponse.close());
  });
}

void _process(UnparsedRequest req, _ChainImpl chain, Completer completer) {
  runZoned(() {
        
    runZoned(() {
      chain._init().then((shelf.Response resp) {
        _logger.finer("Closed request for: ${request.url}");
        completer.complete(response);
      });
    }, onError: (e, s) {
      _handleError("Failed to handle request.", e, stack: s, req: req).then((_) =>
          completer.complete(response));
    });

  }, zoneValues: {
    #request: req,
    #chain: chain,
    #state: new _RequestState()
  });
}

Future _handleError(String message, Object error, {StackTrace stack, Request req, 
                  int statusCode, Level logLevel: Level.SEVERE}) {
  _logger.log(logLevel, message, error, stack);

  return new Future.sync(() {
    if (req != null) {
          
      if (statusCode == null) {
        if (error is RequestException) {
          statusCode = HttpStatus.BAD_REQUEST;
        } else {
          statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
        }
      }

      _RequestState state = Zone.current[#state];
      if (!state.errorHandlerInvoked) {
        state.errorHandlerInvoked = true;
        return _notifyError(statusCode, req.url.path, error, stack);
      }
    }
  });
}

Future<bool> _verifyRequest(_Target target, UnparsedRequest req) {
  
  if (target == null) {
    return new Future.value(true);
  }
  
  //verify method
  if (!target.route.methods.contains(req.method)) {
    return _handleError("Invalid request", 
        new RequestException(target.handlerName, 
            "${req.method} method not allowed for this target"), req: req, 
                statusCode: HttpStatus.METHOD_NOT_ALLOWED, logLevel: Level.FINE).
            then((_) => false);
  }
  //verify multipart
  if (req.isMultipart && !target.route.allowMultipartRequest) {
    return _handleError("Invalid request", 
        new RequestException(target.handlerName, 
            "multipart requests are not allowed for this target"), 
                req: req, logLevel: Level.FINE).
            then((_) => false);
  }
  //verify body type
  if (target.bodyType != null && target.bodyType != req.bodyType) {
    return _handleError("Invalid request", 
       new RequestException(target.handlerName, 
           "${req.bodyType} data not supported for this target"),
              req: req, logLevel: Level.FINE).
           then((_) => false);
  }
  
  return new Future.value(true);
}

Future _runTarget(_Target target, UnparsedRequest req, shelf.Handler handler) {

  return _verifyRequest(target, req).then((bool validRequest) {

    if (!validRequest) {
      return null;
    }
    
    Future f = null;
    if (target != null) {
      f = req.parseBody().then((_) => target.handleRequest(req));
    }
    
    if (f == null) {
      if (handler != null) {
        var r = handler(req.shelfRequest);
        if (r is Future) {
          f = r.then((resp) => response = resp);
        } else {
          response = r;
          f = new Future.value();
        }
      } else {
        _logger.fine("resource not found: ${req.url}");

        f = _notifyError(HttpStatus.NOT_FOUND, req.url.path);
      }
    }

    return f;

  });

}

class _ChainImpl implements Chain {

  shelf.Handler _initHandler;
  shelf.Handler _finalHandler;
  
  List<_Interceptor> _interceptors;
  _Target _target;
  
  _Interceptor _currentInterceptor;
  UnparsedRequest _request;

  bool _bodyTypeParsed = false;
  bool _targetInvoked = false;
  bool _interrupted = false;

  final Completer _completer = new Completer();
  
  List _callbacks = [];
  
  dynamic _error;

  _ChainImpl(this._interceptors, this._target, this._request,
             shelf.Pipeline initHandler, this._finalHandler) {
    
    var h = (shelf.Request req) {
      _request.shelfRequest = req;
      _request.attributes.addAll(req.context);
      var c = new Completer();
      next(() => c.complete(response));
      return c.future;
    };
    
    if (initHandler != null) {
      _initHandler = initHandler.addHandler(h);
    } else {
      _initHandler = h;
    }
    
  }
  
  dynamic get error => _error;
  
  Future _invokeCallbacks() {
    return Future.forEach(_callbacks.reversed, (c) {
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
    }).then((_) => _callbacks.clear());
  }
  
  Future<shelf.Response> _init() {
    return new Future.sync(() => _initHandler(_request.shelfRequest));
  }

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

      if (!_interceptors.isEmpty) {
        _currentInterceptor = _interceptors.removeAt(0);
        new Future(() {
          if (_currentInterceptor.parseRequestBody) {
            return _request.parseBody().then((_) =>
                _currentInterceptor.runInterceptor());
          } else {
            _currentInterceptor.runInterceptor();
          }
        });
      } else {
        _currentInterceptor = null;
        _targetInvoked = true;
        new Future(() {
          _runTarget(_target, request, _finalHandler).then((_) {
            if (!_interrupted && !Zone.current[#state].requestAborted) {
              return _invokeCallbacks();
            }
          }).catchError((e, s) {
            if (!_interrupted) {
              _error = e;
              return _handleError("Failed to execute ${_target.handlerName}", e, 
                  stack: s, req: request).then((_) => _invokeCallbacks());
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
  bool abortIfChainInterrupted: false, List<_ResponseHandlerInstance> processors}) {

  Completer completer = new Completer();
  
  if (abortIfChainInterrupted && chain.interrupted) {
    
    completer.complete();
    
  } else if (respValue == null) {
    
    if (processors != null && !processors.isEmpty) {
      respValue = processors.fold(respValue, (v, p) =>
          p.processor(p.metadata, p.handlerName, v, _injector));
      _writeResponse(respValue, responseType, 
          abortIfChainInterrupted: abortIfChainInterrupted).then((_) =>
              completer.complete());
    } else {

      response = new shelf.Response(statusCode);
      completer.complete();
    
    }

  } else if (respValue is Future) {

    (respValue as Future).then((fValue) =>
      _writeResponse(fValue, responseType, 
          abortIfChainInterrupted: abortIfChainInterrupted).then((_) =>
              completer.complete()));

  } else if (processors != null && !processors.isEmpty) { 
    
    respValue = processors.fold(respValue, (v, p) =>
        p.processor(p.metadata, p.handlerName, v, _injector));
    _writeResponse(respValue, responseType, 
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
    var match = e.urlPattern.firstMatch(path);
    if (match != null) {
      return match[0] == path;
    }
    return false;
  }, orElse: () => null);
}

Future _notifyError(int statusCode, String resource, [Object error, StackTrace stack]) {

  return new Future.sync(() {
    _ErrorHandler handler = _findErrorHandler(statusCode, request.url.path);
    if (handler != null) {
      return handler.errorHandler();
    } else {
      _writeErrorPage(statusCode, resource, error, stack);
    }
  });
}

void _writeErrorPage(int statusCode, String resource, [Object error, StackTrace stack]) {

  String description = _getStatusDescription(statusCode);

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
      <pre>${error}${stack != null ? "\n\n" + stack.toString() : ""}</pre>
    </div>
  </div>
  <div class="footer">Redstone Server - 2014 - Luiz Mineo</div>
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