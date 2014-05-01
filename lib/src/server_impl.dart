part of bloodless_server;

typedef Future _RequestHandler(UrlMatch match, Request request);
typedef void _RunInterceptor();
typedef void _HandleError();
typedef dynamic _ConvertFunction(String value, dynamic defaultValue);

var _intType = reflectClass(int);
var _doubleType = reflectClass(double);
var _boolType = reflectClass(bool);
var _stringType = reflectClass(String);
var _dynamicType = reflectType(dynamic);
var _voidType = currentMirrorSystem().voidType;

final List<_Target> _targets = [];
final List<_Interceptor> _interceptors = [];
final Map<int, _ErrorHandler> _errorHandlers = {};

VirtualDirectory _virtualDirectory;

class _RequestImpl extends UnparsedRequest {

  HttpRequest _httpRequest;
  HttpRequestBody _requestBody;
  String _bodyType;
  bool _isMultipart = false;
  
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
    #chain: chain
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

      _notifyError(req.response, req.uri.path, error, stack);
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

Future<bool> _runTarget(_Target target, UnparsedRequest req) {

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

class _Target {
  
  final UrlTemplate urlTemplate;
  final _RequestHandler handler;
  
  final String handlerName;
  final Route route;
  final String bodyType;
  
  UrlMatch _match;

  _Target(this.urlTemplate, this.handlerName, 
          this.handler, this.route, this.bodyType);
  
  bool match(Uri uri) {
    _match = urlTemplate.match(uri.path);
    return _match !=null;
  }

  Future handleRequest(Request req) {
    UrlMatch match;
    if (_match == null) {
      match = urlTemplate.match(req.httpRequest.uri.path);
      if (match == null || !match.tail.isEmpty) {
        return null;
      }
    } else {
      match = _match;
    }

    return handler(match, req);
  }
}

class _TargetParam {

  final dynamic value;
  final Symbol name;

  _TargetParam(this.value, [this.name]);

}

class _Interceptor {
  
  final RegExp urlPattern;
  final String interceptorName;
  final int chainIdx;
  final bool parseRequestBody;
  final _RunInterceptor runInterceptor;

  _Interceptor(this.urlPattern, this.interceptorName, 
               this.chainIdx, this.parseRequestBody, 
               this.runInterceptor);

}

class _ErrorHandler {
  
  final int statusCode;
  final String handlerName;
  final _HandleError errorHandler;

  _ErrorHandler(this.statusCode, this.handlerName, 
                this.errorHandler);

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

  _ChainImpl(this._interceptors, this._target, this._request);
  
  Future<bool> get done => _completer.future;

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
            return Future.forEach(_callbacks.reversed, (c) {
              var f = c();
              if (f != null && f is Future) {
                return f;
              }
              return new Future.value();
            }).then((_) {
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
        then((_) => _completer.complete(true));
  }
  
  bool get interrupted => _interrupted;

}

class _ParamProcessors {
  
  final List<Function> processors;
  final String bodyType;
  
  _ParamProcessors(this.bodyType, this.processors);
  
}

void _scanHandlers([List<Symbol> libraries]) {
  
  var mirrorSystem = currentMirrorSystem();
  var libsToScan;
  if (libraries != null) {
    libsToScan = new List.from(libraries.map((l) => mirrorSystem.findLibrary(l)));
  } else {
    libsToScan = mirrorSystem.libraries.values;
  }

  libsToScan.forEach((LibraryMirror lib) {
    lib.declarations.values.forEach((DeclarationMirror declaration) {
      if (declaration is MethodMirror) {
        MethodMirror method = declaration;
        
        method.metadata.forEach((InstanceMirror metadata) {
          if (metadata.reflectee is Route) {
            _configureTarget(metadata.reflectee as Route, lib, method);
          } else if (metadata.reflectee is Interceptor) {
            _configureInterceptor(metadata.reflectee as Interceptor, lib, method);
          } else if (metadata.reflectee is ErrorHandler) {
            _configureErrorHandler(metadata.reflectee as ErrorHandler, lib, method);
          }
        });
      } else if (declaration is ClassMirror) {
        ClassMirror clazz = declaration;

        clazz.metadata.forEach((InstanceMirror metadata) {
          if (metadata.reflectee is Group) {
            _configureGroup(metadata.reflectee as Group, clazz);
          }
        });
      }
    });
  });

  _interceptors.sort((i1, i2) => i1.chainIdx - i2.chainIdx);
}

void _clearHandlers() {

  _targets.clear();
  _interceptors.clear();
  _errorHandlers.clear();

}

void _configureGroup(Group group, ClassMirror clazz) {

  var className = MirrorSystem.getName(clazz.qualifiedName);
  _logger.info("Found group: $className");

  InstanceMirror instance = null;
  try {
    instance = clazz.newInstance(new Symbol(""), []);
  } catch(e) {
    throw new SetupException(className, "Failed to create a instance of the group. Does $className have a default constructor with no arguments?");
  }

  String prefix = group.urlPrefix;
  if (prefix.endsWith("/")) {
    prefix = prefix.substring(0, prefix.length - 1);
  }

  clazz.instanceMembers.values.forEach((MethodMirror method) {

    method.metadata.forEach((InstanceMirror metadata) {
      if (metadata.reflectee is Route) {
        
        Route route = metadata.reflectee as Route;
        String urlTemplate = route.urlTemplate;
        if (!urlTemplate.startsWith("/")) {
          urlTemplate = "$prefix/$urlTemplate";
        } else {
          urlTemplate = "$prefix$urlTemplate";
        }
        var newRoute = new Route._fromGroup(urlTemplate, route.methods, route.responseType, route.allowMultipartRequest);

        _configureTarget(newRoute, instance, method);
      } else if (metadata.reflectee is Interceptor) {

        Interceptor interceptor = metadata.reflectee as Interceptor;
        String urlPattern = interceptor.urlPattern;
        if (!urlPattern.startsWith("/")) {
          urlPattern = "$prefix/$urlPattern";
        } else {
          urlPattern = "$prefix$urlPattern";
        }
        var newInterceptor = new Interceptor._fromGroup(urlPattern, interceptor.chainIdx, interceptor.parseRequestBody);

        _configureInterceptor(newInterceptor, instance, method);
      }
    });

  });
}

void _configureInterceptor(Interceptor interceptor, ObjectMirror owner, MethodMirror handler) {

  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  if (!handler.parameters.where((p) => !p.isOptional).isEmpty) {
    throw new SetupException(handlerName, "Interceptors must have no required arguments.");
  }

  var caller = () {

    _logger.finer("Invoking interceptor: $handlerName");
    owner.invoke(handler.simpleName, []);

  };

  var name = MirrorSystem.getName(handler.qualifiedName);
  _interceptors.add(new _Interceptor(new RegExp(interceptor.urlPattern), name,
                                     interceptor.chainIdx, interceptor.parseRequestBody, 
                                     caller));

  _logger.info("Configured interceptor for ${interceptor.urlPattern} : $handlerName");
}

void _configureErrorHandler(ErrorHandler errorHandler, ObjectMirror owner, MethodMirror handler) {

  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  if (!handler.parameters.where((p) => !p.isOptional).isEmpty) {
    throw new SetupException(handlerName, "error handlers must have no required arguments.");
  }

  var caller = () {

    _logger.finer("Invoking error handler: $handlerName");
    owner.invoke(handler.simpleName, []);

  };

  var name = MirrorSystem.getName(handler.qualifiedName);
  _errorHandlers[errorHandler.statusCode] = new _ErrorHandler(errorHandler.statusCode, name,
                                                              caller);

  _logger.info("Configured error handler for status ${errorHandler.statusCode} : $handlerName");
}

void _configureTarget(Route route, ObjectMirror owner, MethodMirror handler) {

  var paramProcessors = _buildParamProcesors(handler);
  var handlerName = MirrorSystem.getName(handler.qualifiedName);

  var caller = (UrlMatch match, Request request) {
    
    _logger.finer("Preparing to execute target: $handlerName");

    return new Future(() {

      var httpResp = request.response;
      var pathParams = match.parameters;
      var queryParams = request.queryParams;
      
      var posParams = [];
      var namedParams = {};
      paramProcessors.processors.forEach((f) {
        var targetParam = f(pathParams, queryParams, request.bodyType, request.body);
        if (targetParam.name == null) {
          posParams.add(targetParam.value);
        } else {
          namedParams[targetParam.name] = targetParam.value;
        }
      });

      _logger.finer("Invoking target $handlerName");
      InstanceMirror resp = owner.invoke(handler.simpleName, posParams, namedParams);

      if (resp.type == _voidType || chain.interrupted) {
        return null;
      }

      var respValue = resp.reflectee;

      _logger.finer("Writing response for target $handlerName");
      return _writeResponse(respValue, httpResp, route.responseType);

    });    

  };

  _targets.add(new _Target(new UrlTemplate(route.urlTemplate), handlerName, caller, route, paramProcessors.bodyType));

  _logger.info("Configured target for ${route.urlTemplate} : $handlerName");
}

Future _writeResponse(respValue, HttpResponse httpResp, String responseType, {int statusCode}) {

  Completer completer = new Completer();
  
  if (respValue == null) {

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

_ParamProcessors _buildParamProcesors(MethodMirror handler) {

  String bodyType = null;

  List processors = new List.from(handler.parameters.map((ParameterMirror param) {
    var handlerName = MirrorSystem.getName(handler.qualifiedName);
    var paramSymbol = param.simpleName;
    var name = param.isNamed ? paramSymbol : null;

    if (!param.metadata.isEmpty) {
      var metadata = param.metadata[0];

      if (metadata.reflectee is Body) {

        var body = metadata.reflectee as Body;
        if (bodyType != null) {
          throw new SetupException(handlerName, "Invalid parameters: Only one parameter can be annotated with @Body");
        }
        bodyType = body.type;

        return (urlParams, queryParams, reqBodyType, reqBody) {
          return new _TargetParam(reqBody, name);
        };

      } else if (metadata.reflectee is QueryParam) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var convertFunc = _buildConvertFunction(param.type);
        var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;

        return (urlParams, queryParams, reqBodyType, reqBody) {
          var value = (queryParams as Map)[(metadata.reflectee as QueryParam).name];
          try {
            value = convertFunc(value, defaultValue);
          } catch(e) {
            throw new RequestException(handlerName, "Invalid value for $paramName: $value");
          }
          return new _TargetParam(value, name);
        };
      }
    }

    var convertFunc = _buildConvertFunction(param.type);
    var paramName = MirrorSystem.getName(paramSymbol);
    var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;

    return (urlParams, queryParams, reqBodyType, reqBody) {
      var value = urlParams[paramName];
      try {
        value = convertFunc(value, defaultValue);
      } catch(e) {
        throw new RequestException(handlerName, "Invalid value for $paramName: $value");
      }
      return new _TargetParam(value, name);
    };
  }));
  
  return new _ParamProcessors(bodyType, processors);
}

_ConvertFunction _buildConvertFunction(paramType) {
  if (paramType == _stringType || paramType == _dynamicType) {
    return (String value, defaultValue) => value != null ? value : defaultValue;
  }
  if (paramType == _intType) {
    return (String value, defaultValue) => value != null ? int.parse(value) : defaultValue;
  }
  if (paramType == _doubleType) {
    return (String value, defaultValue) => value != null ? double.parse(value) : defaultValue;
  }
  if (paramType == _boolType) {
    return (String value, defaultValue) => value != null ? value.toLowerCase() == "true" : defaultValue;
  }

  return (String value, defaultValue) => null;
}

void _notifyError(HttpResponse resp, String resource, [Object error, StackTrace stack]) {
  int statusCode = resp.statusCode;

  _ErrorHandler handler = _errorHandlers[statusCode];
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
  <title>Bloodless Server - ${description != null ? description : statusCode}</title>
  <style>
    body, html {
      margin: 0px;
      padding: 0px;
      border: 0px;
    }
    .header {
      height:100px;
      background-color:steelblue;
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
  <div class="footer">Bloodless Server - 2014 - Luiz Mineo</div>
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