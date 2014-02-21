library bloodless_server;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';
import 'dart:convert' as conv;

import 'package:http_server/http_server.dart';
import 'package:route_hierarchical/url_matcher.dart';
import 'package:route_hierarchical/url_template.dart';
import 'package:logging/logging.dart';

const String GET = "GET";
const String POST = "POST";

const String JSON = "application/json";
const String FORM = "form";
const String TEXT = "text/plain";

const String _DEFAULT_ADDRESS = "0.0.0.0";
const int _DEFAULT_PORT = 8080;

final Logger _logger = new Logger("bloodless_server");


class Route {
  
  final String urlTemplate;
  
  final List<String> methods;

  final String responseType;

  const Route(String this.urlTemplate, 
              {this.methods: const [GET],
               this.responseType});
}

class Body {

  final String type;

  const Body(String this.type);

}

class FormParam {

  final String name;

  const FormParam(String this.name);

}

class QueryParam {
  
  final String name;

  const QueryParam(String this.name);
}


class Interceptor {

  final String url;

  const Interceptor(String this.url);

}

class ErrorHandler {

  final int statusCode;

  const ErrorHandler(int this.statusCode);

}

class Request {

  HttpRequestBody _reqBody;
  Map<String, String> _pathParams;
  Map<String, String> _queryParams;

  Request(HttpRequestBody this._reqBody, 
          Map<String, String> this._pathParams,
          Map<String, String> this._queryParams);

  String get method => _reqBody.request.method;

  Map<String, String> get queryParams => _queryParams;

  Map<String, String> get pathParams => _pathParams;

  String get bodyType => _reqBody.type;

  dynamic get body => _reqBody.body;

  HttpHeaders get headers => _reqBody.request.headers;

  HttpSession get session => _reqBody.request.session;

  HttpResponse get response => _reqBody.request.response;

  HttpRequest get httpRequest => _reqBody.request;

}

class SetupException implements Exception {

  final String handler;
  final String message;

  SetupException(String this.handler, String this.message);

  String toString() => "SetupException: [$handler] $message";

}

class RequestException implements Exception {
  
  final String handler;
  final String message;

  RequestException(String this.handler, String this.message);

  String toString() => "RequestException: [$handler] $message";
}


Request get request => Zone.current[#request];


Future<HttpServer> start([address = _DEFAULT_ADDRESS, int port = _DEFAULT_PORT]) {
  return new Future(() {
    
    try {
      _scanTargets();
    } catch (e) {
      _handleError("Failed to configure targets.", e);
      throw e;
    }

    return HttpServer.bind(address, port).then((server) {
      server.transform(new HttpBodyHandler())
          .listen((HttpRequestBody req) {
            _handleRequest(req);
          });

      return server;
    });
  });
}

void attach(httpRequest) {

}

var _intType = reflectClass(int);
var _doubleType = reflectClass(double);
var _boolType = reflectClass(bool);
var _stringType = reflectClass(String);
var _dynamicType = reflectType(dynamic);
var _voidType = currentMirrorSystem().voidType;

final List<_Target> _targets = [];

void _handleRequest(HttpRequestBody req) {
  bool found = false;
  for (var target in _targets) {
    if (target.handleRequest(req)) {
      found = true;
      break;
    }
  }

  if (!found) {
    try {
      var resp = req.request.response;
      resp.statusCode = HttpStatus.NOT_FOUND;
      resp.close();
    } catch(e) {
      _handleError("Failed to send response to user.", e);
    }
  }
}

void _handleError(String message, Object error, {StackTrace stack, HttpRequestBody req}) {
  _logger.severe(error, stack);

  if (req != null) {
    try {
      var resp = req.request.response;

      if (error is RequestException) {
        resp.statusCode = HttpStatus.BAD_REQUEST;
      } else {
        resp.statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
      }

      resp.close();
    } catch(e) {
      _logger.severe(e);
    }
  }
}

typedef void _RequestHandler(UrlMatch match, HttpRequestBody request);

typedef _TargetParam _ParamProcessor(Map<String, String> urlParams,
                                     Map<String, String> queryParams, 
                                     String bodyType, dynamic reqBody);

typedef dynamic _ConvertFunction(String value);

class _Target {
  
  final UrlTemplate urlTemplate;
  final _RequestHandler handler;

  _Target(this.urlTemplate, this.handler);

  bool handleRequest(HttpRequestBody req) {
    UrlMatch match = urlTemplate.match(req.request.uri.path);
    if (match == null || !match.tail.isEmpty) {
      return false;
    }

    handler(match, req);
    return true; 
  }
}

class _TargetParam {

  final dynamic value;
  final Symbol name;

  _TargetParam(this.value, [this.name]);

}

void _scanTargets() {
  currentMirrorSystem().libraries.values.forEach((LibraryMirror lib) {
    lib.topLevelMembers.values.forEach((MethodMirror method) {
      method.metadata.forEach((InstanceMirror metadata) {
        if (metadata.reflectee is Route) {
          _configureTarget(metadata.reflectee as Route, lib, method);
        }
      });
    });
  });
}

void _configureTarget(Route route, LibraryMirror lib, MethodMirror handler) {

  var paramProcessors = _buildParamProcesors(handler);

  var caller = (UrlMatch match, HttpRequestBody request) {
    
    var httpResp = request.request.response;
    var pathParams = match.parameters;
    var queryParams = request.request.uri.queryParameters;

    runZoned(() {
      if (!route.methods.contains(request.request.method)) {
        httpResp.statusCode = HttpStatus.METHOD_NOT_ALLOWED;
        httpResp.close();
        return;
      }
      
      var posParams = [];
      var namedParams = {};
      paramProcessors.map((f) => 
          f(pathParams, queryParams, request.type, request.body))
            .forEach((_TargetParam targetParam) {
              if (targetParam.name == null) {
                posParams.add(targetParam.value);
              } else {
                namedParams[targetParam.name] = targetParam.value;
              }
            });

      InstanceMirror resp = lib.invoke(handler.simpleName, posParams, namedParams);

      if (resp.type == _voidType) {
        httpResp.close();
        return;
      }

      var respValue = resp.reflectee;
      _writeResponse(respValue, httpResp, route);

    }, zoneValues: {
      #request: new Request(request, pathParams, queryParams)
    }, onError: (e, s) {
      _handleError("Failed to handle request.", e, stack: s, req: request);
    });

  };

  _targets.add(new _Target(new UrlTemplate(route.urlTemplate), caller));
}

void _writeResponse(respValue, HttpResponse httpResp, Route route) {

  if (respValue == null) {
    httpResp.close();
  } else if (respValue is Future) {
    (respValue as Future).then((fValue) {
      _writeResponse(fValue, httpResp, route);
    });
  } else if (respValue is Map || respValue is List) {
    respValue = conv.JSON.encode(respValue);
    if (route.responseType != null) {
      httpResp.headers.add(HttpHeaders.CONTENT_TYPE, route.responseType);
    } else {
      httpResp.headers.contentType = new ContentType("application", "json", charset: "UTF-8");
    }
    httpResp.write(respValue);
    httpResp.close();
  } else {
    if (route.responseType != null) {
      httpResp.headers.add(HttpHeaders.CONTENT_TYPE, route.responseType);
    } else {
      httpResp.headers.contentType = new ContentType("text", "plain");
    }
    httpResp.write(respValue);
    httpResp.close();
  }

}

List<_ParamProcessor> _buildParamProcesors(MethodMirror handler) {
  
  var bodyParam = false;
  var bodyType = null;

  return new List.from(handler.parameters.map((ParameterMirror param) {
    var handlerName = MirrorSystem.getName(handler.qualifiedName);
    var paramSymbol = param.simpleName;
    var name = param.isNamed ? paramSymbol : null;

    if (!param.metadata.isEmpty) {
      var metadata = param.metadata[0];

      if (metadata.reflectee is Body) {

        var body = metadata.reflectee as Body;
        if (bodyParam) {
          throw new SetupException(handlerName, "Invalid parameters: Only one parameter can be annotated with @Body");
        } else if (bodyType != null && bodyType != body.type) {
          var paramName = MirrorSystem.getName(paramSymbol);
          throw new SetupException(handlerName, "Invalid parameters: $paramName is accesing the request's body as ${body.type}, "
              "but a previous parameter is acessing the body as $bodyType");
        }
        bodyParam = true;
        bodyType = body.type;

        return (urlParams, queryParams, reqBodyType, reqBody) {
          if (bodyType != reqBodyType) {
            throw new RequestException(handlerName, "$reqBodyType data not supported for this target");
          } 
          return new _TargetParam(reqBody, name);
        };

      } else if (metadata.reflectee is FormParam) {
        var paramName = MirrorSystem.getName(paramSymbol);
        if (bodyType != null && bodyType != FORM) {
          throw new SetupException(handlerName, "Invalid parameters: $paramName is accesing the request's body as $FORM, "
              "but a previous parameter is acessing the body as $bodyType");
        }

        var convertFunc = _buildConvertFunction(param.type);

        return (urlParams, queryParams, reqBodyType, reqBody) {
          if (bodyType != reqBodyType) {
            throw new RequestException(handlerName, "$reqBodyType data not supported for this target");
          } 
          var value = (reqBody as Map)[(metadata.reflectee as FormParam).name];
          if (value != null) {
            try {
              value = convertFunc(value);
            } catch(e) {
              throw new RequestException(handlerName, "Invalid value for $paramName: $value");
            }
          }
          return new _TargetParam(value, name);
        };
      } else if (metadata.reflectee is QueryParam) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var convertFunc = _buildConvertFunction(param.type);

        return (urlParams, queryParams, reqBodyType, reqBody) {
          var value = (reqBody as Map)[(metadata.reflectee as QueryParam).name];
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
        value = convertFunc(value);
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
}