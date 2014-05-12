part of redstone_server;

typedef Future _RequestHandler(UrlMatch match, Request request);
typedef void _RunInterceptor();
typedef void _HandleError();
typedef dynamic _ConvertFunction(String value, dynamic defaultValue);

VirtualDirectory _virtualDirectory;

class _RequestState {
  
  bool errorHandlerInvoked = false;
  
}

class _RequestImpl extends UnparsedRequest {

  HttpRequest _httpRequest;
  HttpRequestBody _requestBody;
  String _bodyType;
  bool _isMultipart = false;
  final Map _attributes = {};
  
  Future _bodyParsed = null;
  
  _RequestImpl(this._httpRequest) {
    _parseBodyType();
  }
  
  void _parseBodyType() {
    ContentType contentType = _httpRequest.headers.contentType;
    if (contentType == null) {
      return;
    }
    switch (contentType.primaryType) {
      case "text":
        _bodyType = TEXT;
        break;
      case "application":
        switch (contentType.subType) {
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
        switch (contentType.subType) {
          case "form-data":
            _bodyType = FORM;
            break;
        }
        break;
    }
  }
  
  get body => _requestBody != null ? _requestBody.body : null;

  String get bodyType => _bodyType;
  
  bool get isMultipart => _isMultipart;

  HttpHeaders get headers => _httpRequest.headers;

  HttpRequest get httpRequest => _httpRequest;

  Map get attributes => _attributes;
  
  String get method => _httpRequest.method;

  Future parseBody() {
    if (_bodyParsed != null) {
      return _bodyParsed;
    }
    
    _bodyParsed = HttpBodyHandler.processRequest(_httpRequest).then((HttpRequestBody reqBody) {
      _requestBody = reqBody;
      return reqBody.body;
    });
    return _bodyParsed;
  }

  Map<String, String> get queryParams => _httpRequest.uri.queryParameters;

  HttpResponse get response => _httpRequest.response;

  HttpSession get session => _httpRequest.session;
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

Future<HttpResponse> _dispatchRequest(UnparsedRequest req) {
  
  var completer = new Completer();
  
  Chain chain;
  try {
    
    List<_Interceptor> interceptors = _getInterceptors(req.httpRequest.uri);
    _Target target = _getTarget(req.httpRequest.uri);

    chain = new _ChainImpl(interceptors, target, req);
  } catch(e, s) {
    _handleError("Failed to handle request.", e, stack: s, req: req.httpRequest);
    completer.completeError(e, s);
    return completer.future;
  }
    
  _process(req, chain, completer);
    
  return completer.future;
}

void _process(UnparsedRequest req, Chain chain, Completer completer) {
  runZoned(() {
        
    runZoned(() {
      chain.done.then((_) {
        _closeResponse();
        _logger.finer("Closed request for: ${request.httpRequest.uri}");
        completer.complete(req.response);
      });
      chain.next();
    }, onError: (e, s) {
      _handleError("Failed to handle request.", e, stack: s, req: req.httpRequest);
      _closeResponse();
      completer.complete(req.response);
    });

  }, zoneValues: {
    #request: req,
    #chain: chain,
    #state: new _RequestState()
  });
}

void _closeResponse() {
  try {
    request.response.close();
  } catch (_) {
    //response already closed
  }
}

void _handleError(String message, Object error, {StackTrace stack, HttpRequest req}) {
  _logger.severe(message, error, stack);

  if (req != null) {
    var resp = req.response;
    try {

      if (error is RequestException) {
        resp.statusCode = HttpStatus.BAD_REQUEST;
      } else {
        resp.statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
      }

      _RequestState state = Zone.current[#state];
      if (!state.errorHandlerInvoked) {
        state.errorHandlerInvoked = true;
        _notifyError(req.response, req.uri.path, error, stack);
      }
    } catch(e, s) {
      _logger.severe("Failed to handle error", e, s);
    }
  }
}

bool _verifyRequest(_Target target, UnparsedRequest req) {
  var resp = req.response;
  
  if (target == null) {
    return true;
  }
  
  //verify method
  if (!target.route.methods.contains(req.method)) {
    resp.statusCode = HttpStatus.METHOD_NOT_ALLOWED;
    _notifyError(resp, req.httpRequest.uri.path);
    return false;
  }
  //verify multipart
  if (req.isMultipart && !target.route.allowMultipartRequest) {
    resp.statusCode = HttpStatus.BAD_REQUEST;
    _notifyError(resp, req.httpRequest.uri.path, 
        new RequestException(target.handlerName, 
            "multipart requests are not allowed for this target"));
    return false;
  }
  //verify body type
  if (target.bodyType != null && target.bodyType != req.bodyType) {
    resp.statusCode = HttpStatus.BAD_REQUEST;
    _notifyError(resp, req.httpRequest.uri.path, 
        new RequestException(target.handlerName, 
            "${req.bodyType} data not supported for this target"));
    return false;
  }
  
  return true;
}

Future _runTarget(_Target target, UnparsedRequest req) {

  return new Future(() {

    if (!_verifyRequest(target, req)) {
      return null;
    }
    Future f = null;
    if (target != null) {
      f = req.parseBody().then((_) => target.handleRequest(req));
    }
    
    if (f == null) {
      try {
        if (_virtualDirectory != null) {
          _logger.fine("Forwarding request to VirtualDirectory");
          f = _virtualDirectory.serveRequest(req.httpRequest);
        } else {
          _logger.fine("Resource not found: ${req.httpRequest.uri}");
          req.response.statusCode = HttpStatus.NOT_FOUND;
          _notifyError(req.response, req.httpRequest.uri.path);
          f = new Future.value();
        }
      } catch(e) {
        _handleError("Failed to send response to user.", e);
        f = new Future.value();
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
  
  bool _targetInvoked = false;
  bool _interrupted = false;

  final Completer _completer = new Completer();
  
  List _callbacks = [];
  
  dynamic _error;

  _ChainImpl(this._interceptors, this._target, this._request);
  
  Future<bool> get done => _completer.future;
  
  dynamic get error => _error;
  
  Future _invokeCallbacks() {
    return Future.forEach(_callbacks.reversed, (c) {
      var f = c();
      if (f != null && f is Future) {
        return f;
      }
      return new Future.value();
    });
  }

  void next([callback()]) {
    new Future.sync(() {
      if (_interrupted) {
        var name = _currentInterceptor != null ? _currentInterceptor.interceptorName : null;
        throw new ChainException(request.httpRequest.uri.path, 
                                 "invalid state: chain already interrupted",
                                 interceptorName: name);
      }
      if (_interceptors.isEmpty && _targetInvoked) {
        throw new ChainException(request.httpRequest.uri.path, "chain.next() must be called from an interceptor.");
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
          _runTarget(_target, request).then((_) {
            return _invokeCallbacks().then((_) {
              if (!interrupted) {
                _completer.complete();
              }
            });
          }).catchError((e, s) {
            _error = e;
            _handleError("Failed to execute ${_target.handlerName}", e, 
                stack: s, req: request.httpRequest);
            return _invokeCallbacks().then((_) {
              if (!interrupted) {
                _completer.complete();
              }
            });
          });
        });
      }
      
    });
  }

  void interrupt({int statusCode: HttpStatus.OK, Object response, String responseType}) {
    if (_interrupted) {
      var name = _currentInterceptor != null ? _currentInterceptor.interceptorName : null;
      throw new ChainException(request.httpRequest.uri.path, 
                               "invalid state: chain already interrupted",
                               interceptorName: name);
    }

    _interrupted = true;

    _writeResponse(response, request.response, responseType, statusCode: statusCode).
        then((_) => _completer.complete());
  }
  
  bool get interrupted => _interrupted;

}

Future _writeResponse(respValue, HttpResponse httpResp, String responseType, {int statusCode, 
  bool abortIfChainInterrupted: false}) {

  Completer completer = new Completer();
  
  if (abortIfChainInterrupted && chain.interrupted) {
    
    completer.complete();
    
  } else if (respValue == null) {

    if (statusCode != null) {
      httpResp.statusCode = statusCode;
    }
    completer.complete();

  } else if (respValue is Future) {

    (respValue as Future).then((fValue) =>
      _writeResponse(fValue, httpResp, responseType).then((v) =>
          completer.complete(v)));

  } else if (respValue is Map || respValue is List) {

    if (statusCode != null) {
      httpResp.statusCode = statusCode;
    }
    respValue = conv.JSON.encode(respValue);
    try {
      if (responseType != null) {
        httpResp.headers.set(HttpHeaders.CONTENT_TYPE, responseType);
      } else {
        httpResp.headers.contentType = new ContentType("application", "json", charset: "UTF-8");
      }
    } catch (e) {
      _logger.finer("Couldn't set the response's content type. Maybe it was already set?");
    }
    httpResp.write(respValue);
    completer.complete();

  } else if (respValue is File) { 
    
    if (statusCode != null) {
      httpResp.statusCode = statusCode;
    }
    File f = respValue as File;
    try {
      if (responseType != null) {
        httpResp.headers.set(HttpHeaders.CONTENT_TYPE, responseType);
      } else {
        String contentType = lookupMimeType(f.path);
        httpResp.headers.set(HttpHeaders.CONTENT_TYPE, contentType);
      }
    } catch (e) {
      _logger.finer("Couldn't set the response's content type. Maybe it was already set?", e);
    }
    httpResp.addStream(f.openRead()).then((_) => completer.complete());

  } else {

    if (statusCode != null) {
      httpResp.statusCode = statusCode;
    }
    try {
      if (responseType != null) {
        httpResp.headers.set(HttpHeaders.CONTENT_TYPE, responseType);
      } else {
        httpResp.headers.contentType = new ContentType("text", "plain");
      }
    } catch (e) {
      _logger.finer("Couldn't set the response's content type. Maybe it was already set?");
    }
    httpResp.write(respValue);
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

void _notifyError(HttpResponse resp, String resource, [Object error, StackTrace stack]) {
  int statusCode = resp.statusCode;

  _ErrorHandler handler = _findErrorHandler(statusCode, request.httpRequest.uri.path);
  if (handler != null) {
    handler.errorHandler();
  } else {
    _writeErrorPage(resp, resource, error, stack);
  }
}

void _writeErrorPage(HttpResponse resp, String resource, [Object error, StackTrace stack]) {

  int statusCode = resp.statusCode;
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

  resp.headers.contentType = new ContentType("text", "html");
  resp.write(errorTemplate);
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