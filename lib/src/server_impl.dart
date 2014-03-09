part of bloodless_server;

typedef Future _RequestHandler(UrlMatch match, Request request);
typedef void _RunInterceptor();
typedef void _HandleError();
typedef _TargetParam _ParamProcessor(Map<String, String> urlParams,
                                     Map<String, String> queryParams, 
                                     String bodyType, dynamic reqBody);
typedef dynamic _ConvertFunction(String value);

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

void _handleRequest(HttpRequestBody req) {
  _dispatchRequest(new Request(req, req.request.uri.queryParameters));
}

Future<HttpResponse> _dispatchRequest(Request req) {
  
  var completer = new Completer();
  
  var queryParams, path, chain;
  try {
    queryParams = req.queryParams;
    path = req.httpRequest.uri.path;
    var handlers = _interceptors.where((i) {
      var match = i.urlPattern.firstMatch(path);
      if (match != null) {
        return match[0] == path;
      }
      return false;
    });
    chain = new _ChainImpl(new List.from(handlers));
  } catch(e, s) {
    _handleError("Failed to handle request.", e, stack: s, req: req.httpRequest);
    completer.completeError(e, s);
    return completer.future;
  }

  runZoned(() {

    chain.next().then((targetExecuted) {
      if (targetExecuted) {
        request.response.close();
      }
      _logger.finer("Closed request for: ${request.httpRequest.uri}");
      completer.complete(req.response);
    });

  }, zoneValues: {
    #request: req,
    #chain: chain
  }, onError: (e, s) {
    _handleError("Failed to handle request.", e, stack: s, req: req.httpRequest);
    completer.completeError(e, s);
  });
    
  return completer.future;
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
    } catch(e) {
      _logger.severe(e);
      resp.close();
    }
  }
}

Future<bool> _runTarget(Request req) {

  return new Future.sync(() {

    Future f = null;
    for (var target in _targets) {
      f = target.handleRequest(req);
      if (f != null) {
        break;
      }
    }

    if (f == null) {
      try {
        if (_virtualDirectory != null) {
          _logger.fine("Forwarding request to VirtualDirectory");
          _virtualDirectory.serveRequest(req.httpRequest);
        } else {
          _logger.fine("Resource not found: ${req.httpRequest.uri}");
          _notifyError(req.response, req.httpRequest.uri.path);
        }
      } catch(e) {
        _handleError("Failed to send response to user.", e);
      }

      return false;
    }

    return f.then((_) => true);

  });

}

class _Target {
  
  final UrlTemplate urlTemplate;
  final _RequestHandler handler;

  _Target(this.urlTemplate, this.handler);

  Future handleRequest(Request req) {
    UrlMatch match = urlTemplate.match(req.httpRequest.uri.path);
    if (match == null || !match.tail.isEmpty) {
      return null;
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
  final _RunInterceptor runInterceptor;

  _Interceptor(this.urlPattern, this.interceptorName, 
               this.chainIdx, this.runInterceptor);

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
  _Interceptor _currentInterceptor;
  
  bool _targetInvoked = false;
  bool _interrupted = false;

  List _completers = [];

  _ChainImpl(List<_Interceptor> this._interceptors);

  Future<bool> next() {
    return new Future.sync(() {
      if (_interrupted) {
        var name = _currentInterceptor != null ? _currentInterceptor.interceptorName : null;
        throw new ChainException(request.httpRequest.uri.path, 
                                 "invalid state: chain already interrupted",
                                 interceptorName: name);
      }
      if (_interceptors.isEmpty && _targetInvoked) {
        throw new ChainException(request.httpRequest.uri.path, "chain.next() must be called from an interceptor.");
      }

      Completer completer = new Completer();
      _completers.add(completer);

      if (!_interceptors.isEmpty) {
        _currentInterceptor = _interceptors.removeAt(0);
        new Future(() {
          _currentInterceptor.runInterceptor();
        });
      } else {
        _targetInvoked = true;
        new Future(() {
          _runTarget(request).then((targetExecuted) {
            _completers.reversed.forEach((c) => c.complete(targetExecuted));
          });
        });
      }

      return completer.future;
    });
  }

  void interrupt(int statusCode, {Object response, String responseType}) {
    if (_interrupted) {
      var name = _currentInterceptor != null ? _currentInterceptor.interceptorName : null;
      throw new ChainException(request.httpRequest.uri.path, 
                               "invalid state: chain already interrupted",
                               interceptorName: name);
    }
    if (_targetInvoked) {
      throw new ChainException(request.httpRequest.uri.path, "Invalid state: target already invoked.");
    }

    _interrupted = true;

    _writeResponse(response, request.response, responseType, statusCode: statusCode);
    _completers[0].complete(true);
  }

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

    lib.topLevelMembers.values.forEach((MethodMirror method) {
      method.metadata.forEach((InstanceMirror metadata) {
        if (metadata.reflectee is Route) {
          _configureTarget(metadata.reflectee as Route, lib, method);
        } else if (metadata.reflectee is Interceptor) {
          _configureInterceptor(metadata.reflectee as Interceptor, lib, method);
        } else if (metadata.reflectee is ErrorHandler) {
          _configureErrorHandler(metadata.reflectee as ErrorHandler, lib, method);
        }
      });
    });

    lib.declarations.values.forEach((DeclarationMirror declaration) {
      if (declaration is ClassMirror) {
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
        var newRoute = new Route._fromGroup(urlTemplate, route.methods, route.responseType);

        _configureTarget(newRoute, instance, method);
      } else if (metadata.reflectee is Interceptor) {

        Interceptor interceptor = metadata.reflectee as Interceptor;
        String urlPattern = interceptor.urlPattern;
        if (!urlPattern.startsWith("/")) {
          urlPattern = "$prefix/$urlPattern";
        } else {
          urlPattern = "$prefix$urlPattern";
        }
        var newInterceptor = new Interceptor._fromGroup(urlPattern, interceptor.chainIdx);

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
                                     interceptor.chainIdx, caller));

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

    return new Future.sync(() {

      var httpResp = request.response;
      var pathParams = match.parameters;
      var queryParams = request.queryParams;

      if (!route.methods.contains(request.method)) {
        httpResp.statusCode = HttpStatus.METHOD_NOT_ALLOWED;
        _notifyError(httpResp, request.httpRequest.uri.path);
        return null;
      }
      
      var posParams = [];
      var namedParams = {};
      paramProcessors.map((f) => 
          f(pathParams, queryParams, request.bodyType, request.body))
            .forEach((_TargetParam targetParam) {
              if (targetParam.name == null) {
                posParams.add(targetParam.value);
              } else {
                namedParams[targetParam.name] = targetParam.value;
              }
            });

      _logger.finer("Invoking target $handlerName");
      InstanceMirror resp = owner.invoke(handler.simpleName, posParams, namedParams);

      if (resp.type == _voidType) {
        return null;
      }

      var respValue = resp.reflectee;

      _logger.finer("Writing response for target $handlerName");
      return _writeResponse(respValue, httpResp, route.responseType);

    });    

  };

  _targets.add(new _Target(new UrlTemplate(route.urlTemplate), caller));

  _logger.info("Configured target for ${route.urlTemplate} : $handlerName");
}

Future _writeResponse(respValue, HttpResponse httpResp, String responseType, {int statusCode}) {

  return new Future.sync(() {

    if (respValue == null) {

      if (statusCode != null) {
        httpResp.statusCode = statusCode;
      }
      return null;

    } else if (respValue is Future) {

      return (respValue as Future).then((fValue) {
        _writeResponse(fValue, httpResp, responseType);
      });

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
      return null;

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
      return httpResp.addStream(f.openRead());

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
      return null;

    }

  });

}

List<_ParamProcessor> _buildParamProcesors(MethodMirror handler) {

  var bodyType = null;

  return new List.from(handler.parameters.map((ParameterMirror param) {
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
          if (bodyType != reqBodyType) {
            throw new RequestException(handlerName, "$reqBodyType data not supported for this target");
          } 
          return new _TargetParam(reqBody, name);
        };

      } else if (metadata.reflectee is QueryParam) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var convertFunc = _buildConvertFunction(param.type);

        return (urlParams, queryParams, reqBodyType, reqBody) {
          var value = (queryParams as Map)[(metadata.reflectee as QueryParam).name];
          if (value != null) {
            try {
              value = convertFunc(value);
            } catch(e) {
              throw new RequestException(handlerName, "Invalid value for $paramName: $value");
            }
          }
          return new _TargetParam(value, name);
        };
      }
    }

    var convertFunc = _buildConvertFunction(param.type);
    var paramName = MirrorSystem.getName(paramSymbol);

    return (urlParams, queryParams, reqBodyType, reqBody) {
      var value = urlParams[paramName];
      if (value != null) {
        try {
          value = convertFunc(value);
        } catch(e) {
          throw new RequestException(handlerName, "Invalid value for $paramName: $value");
        }
      }
      return new _TargetParam(value, name);
    };
  }));
}

_ConvertFunction _buildConvertFunction(paramType) {
  if (paramType == _stringType || paramType == _dynamicType) {
    return (String value) => value;
  }
  if (paramType == _intType) {
    return (String value) => int.parse(value);
  }
  if (paramType == _doubleType) {
    return (String value) => double.parse(value);
  }
  if (paramType == _boolType) {
    return (String value) => value.toLowerCase() == "true";
  }

  return (String value) => null;
}

void _notifyError(HttpResponse resp, String resource, [Object error, StackTrace stack]) {
  int statusCode = resp.statusCode;

  _ErrorHandler handler = _errorHandlers[statusCode];
  if (handler != null) {
    handler.errorHandler();
    resp.close();
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
  resp.close();

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