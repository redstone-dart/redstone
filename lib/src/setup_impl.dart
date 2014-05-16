part of redstone_server;

var _intType = reflectClass(int);
var _doubleType = reflectClass(double);
var _boolType = reflectClass(bool);
var _stringType = reflectClass(String);
var _dynamicType = reflectType(dynamic);
var _voidType = currentMirrorSystem().voidType;

final List<_Target> _targets = [];
final List<_Interceptor> _interceptors = [];
final Map<int, List<_ErrorHandler>> _errorHandlers = {};

final List<RedstonePlugin> _plugins = [];
final List<Module> _modules = [];

final Map<String, List<_ParamHandler>> _customParams = {};
final List<_ResponseHandler> _responseProcessors = [];

final Set<Symbol> _blacklistSet = _buildBlacklistSet();

Injector _injector;

class _HandlerCfg<T> {
  
  T metadata;
  _Lib lib;
  MethodMirror method;
  
  _HandlerCfg(this.metadata, this.lib, this.method);
  
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
    UrlMatch match = urlTemplate.match(uri.path);
    if (match != null) {
      if (route.matchSubPaths) {
        if (uri.path.endsWith("/") || match.tail.startsWith("/")) {
          _match = match;
          return true;
        }
      } else {
        if (match.tail.isEmpty) {
          _match = match;
          return true;
        }
      }
    }
    
    if (match != null && match.tail.isEmpty) {
      _match = match;
      return true;
    }
    return false;
  }

  Future handleRequest(Request req) {
    if (_match == null) {
      if (!match(req.httpRequest.uri)) {
        return null;
      }
    }

    return handler(_match, req);
  }
}

class _TargetParam {

  final dynamic value;
  final Symbol name;

  _TargetParam(this.value, [this.name]);

}

class _ParamHandler {
  
  final Type metadataType;
  final ParamProvider parameterProvider;
  
  _ParamHandler(this.metadataType, this.parameterProvider);
  
}

class _ResponseHandler {
  
  final Type metadataType;
  final ResponseProcessor processor;
    
  _ResponseHandler(this.metadataType, this.processor);
    
}

class _ResponseHandlerInstance {
  
  final dynamic metadata;
  final String handlerName;
  final ResponseProcessor processor;
    
  _ResponseHandlerInstance(this.metadata, 
                           this.handlerName, 
                           this.processor);
    
}

class _Interceptor {
  
  final RegExp urlPattern;
  final String interceptorName;
  final List<int> chainIdxByLevel;
  final bool parseRequestBody;
  final _RunInterceptor runInterceptor;

  _Interceptor(this.urlPattern, this.interceptorName, 
               this.chainIdxByLevel, this.parseRequestBody, 
               this.runInterceptor);

}

class _ErrorHandler {
  
  final int statusCode;
  final RegExp urlPattern;
  final String handlerName;
  final _HandleError errorHandler;

  _ErrorHandler(this.statusCode, this.urlPattern, 
                this.handlerName, this.errorHandler);

}

class _ParamProcessors {
  
  final List<Function> processors;
  final String bodyType;
  
  _ParamProcessors(this.bodyType, this.processors);
  
}

class _Group {
  
  final Group metadata;
  final ClassMirror clazz;
  final _Lib lib;
  
  _Group(this.metadata, this.clazz, this.lib);
  
}

class _Lib {
  
  final LibraryMirror def;
  final Install conf;
  final int level;
  
  _Lib(this.def, this.conf, this.level);
  
}

List<_Lib> _scanDependencies(Set<Symbol> cache, _Lib lib) {
  
  var dependencies = [];
  
  lib.def.libraryDependencies.forEach((LibraryDependencyMirror d) {
    if (cache.contains(d.targetLibrary.simpleName) || 
        _blacklistSet.contains(d.targetLibrary.simpleName)) {
      return;
    }
    cache.add(d.targetLibrary.simpleName);
    
    if (d.isImport) {
      Install conf = null;
      for (InstanceMirror m in d.metadata) {
        if (m.reflectee is Ignore) {
          return;
        } else if (m.reflectee is Install) {
          conf = m.reflectee;
          break;
        }
      }
      if (conf == null) {
        conf = new Install.defaultConf();
      }
      if (lib.conf.urlPrefix != null) {
        conf = new Install.conf(
            urlPrefix: conf.urlPrefix != null ? 
                _joinUrl(lib.conf.urlPrefix, conf.urlPrefix) : lib.conf.urlPrefix,
            chainIdx: conf.chainIdx);
      }
      _Lib depLib = new _Lib(d.targetLibrary, conf, lib.level + 1);
      dependencies.add(depLib);
      dependencies.addAll(_scanDependencies(cache, depLib));
    }
  });
  
  return dependencies;
}

List<_Lib> _scanLibraries(Iterable<LibraryMirror> libraries) {
  
  List<_Lib> libs = [];
  
  libraries.where((l) => !_blacklistSet.contains(l.simpleName)).
    forEach((LibraryMirror l) {
        Install conf = null;
        for (InstanceMirror m in l.metadata) {
          if (m.reflectee is Ignore) {
            return;
          } else if (m.reflectee is Install) {
            conf = m.reflectee;
            break;
          }
        }
        if (conf == null) {
          conf = new Install.defaultConf();
        }
        _Lib lib = new _Lib(l, conf, 0);
        libs.add(lib);
        libs.addAll(_scanDependencies(new Set<Symbol>(), lib));
  });
  
  return libs;
  
}

void _scanHandlers([List<Symbol> libraries]) {
  
  //install plugins
  _ManagerImpl manager = new _ManagerImpl();
  manager.installPlugins();
  
  //scan libraries
  var mirrorSystem = currentMirrorSystem();
  List<_Lib> libsToScan;
  if (libraries != null) {
    libsToScan = _scanLibraries(libraries.map((s) => 
        mirrorSystem.findLibrary(s)));
  } else {
    var root = mirrorSystem.isolate.rootLibrary;
    libsToScan = _scanLibraries([root]);
  }
  
  Module baseModule = new Module();
  List<_HandlerCfg<Route>> routes = [];
  List<_HandlerCfg<Interceptor>> interceptors = [];
  List<_HandlerCfg<ErrorHandler>> errors = [];
  List<_Group> groups = [];

  libsToScan.forEach((_Lib lib) {
    
    LibraryMirror def = lib.def;
    
    def.declarations.values.forEach((DeclarationMirror declaration) {
      if (declaration is MethodMirror) {
        MethodMirror method = declaration;
        
        method.metadata.forEach((InstanceMirror metadata) {
          if (metadata.reflectee is Route) {
            routes.add(new _HandlerCfg(metadata.reflectee, lib, method));
          } else if (metadata.reflectee is Interceptor) {
            interceptors.add(new _HandlerCfg(metadata.reflectee, lib, method));
          } else if (metadata.reflectee is ErrorHandler) {
            errors.add(new _HandlerCfg(metadata.reflectee, lib, method));
          }
        });
      } else if (declaration is ClassMirror) {
        ClassMirror clazz = declaration;

        clazz.metadata.forEach((InstanceMirror metadata) {
          if (metadata.reflectee is Group) {
            baseModule.bind(clazz.reflectedType);
            groups.add(new _Group(metadata.reflectee, clazz, lib));
          }
        });
      }
    });
  });
  
  _modules.add(baseModule);
  _injector = defaultInjector(modules: _modules);
  
  routes.forEach((r) => _configureTarget(r.metadata, r.lib.def, r.method, 
      urlPrefix: r.lib.conf.urlPrefix));
  errors.forEach((e) => _configureErrorHandler(e.metadata, e.lib.def, e.method, 
      urlPrefix: e.lib.conf.urlPrefix));
  
  var currentLevel = 0;
  var levelHist = [];
  interceptors.forEach((i) {
    List<int> chainIdxByLevel;
    if (i.lib.level > currentLevel) {
      currentLevel = i.lib.level;
      levelHist.add(i.lib.conf.chainIdx);
    } else if (i.lib.level < currentLevel) {
      currentLevel = i.lib.level;
      levelHist = new List.from(levelHist.sublist(0, currentLevel));
    }
    chainIdxByLevel = new List.from(
        levelHist.where((l) => l != null))
        ..add(i.metadata.chainIdx);
    
    _configureInterceptor(i.metadata, i.lib.def, i.method, 
          urlPrefix: i.lib.conf.urlPrefix, chainIdxByLevel: chainIdxByLevel);
  });
  
  currentLevel = 0;
  levelHist = [];
  groups.forEach((g) {
    List<int> chainIdxByLevel;
    if (g.lib.level > currentLevel) {
      currentLevel = g.lib.level;
      levelHist.add(g.lib.conf.chainIdx);
    } else if (g.lib.level < currentLevel) {
      currentLevel = g.lib.level;
      levelHist = new List.from(levelHist.sublist(0, currentLevel));
    }
    
    _configureGroup(g.metadata, g.clazz, _injector, 
          levelHist, urlPrefix: g.lib.conf.urlPrefix);
  });
  
  _targets.sort((t1, t2) => t1.urlTemplate.compareTo(t2.urlTemplate));
  _interceptors.sort((i1, i2) {
    var idxs1 = i1.chainIdxByLevel;
    var idxs2 = i2.chainIdxByLevel;
    for (int i = 0; i < max(idxs1.length, idxs2.length); i++) {
      int l1 = i < idxs1.length ? idxs1[i] : null;
      int l2 = i < idxs2.length ? idxs2[i] : null;
      if (l1 != null && l2 == null) {
        return -1;
      } else if (l1 == null && l2 != null) {
        return 1;
      } else if (l1 == null && l2 == null) {
        return 0;
      } else if (l1 == l2) {
        continue;
      } else {
        return l1 - l2;
      }
    }
    return 0;
  });
  _errorHandlers.forEach((status, handlers) {
    handlers.sort((e1, e2) {
      if (e1.urlPattern == null && e2.urlPattern == null) {
        return 0;
      } else if (e1.urlPattern == null && e2.urlPattern != null) {
        return 1;
      } else if (e1.urlPattern != null && e2.urlPattern == null) {
        return -1;
      } else {
        var length1 = e1.urlPattern.pattern.split(r'/').length;
        var length2 = e2.urlPattern.pattern.split(r'/').length;
        return length2 - length1;
      }
    });
  });
}

void _clearHandlers() {

  _targets.clear();
  _interceptors.clear();
  _errorHandlers.clear();
  
  _modules.clear();
  _plugins.clear();
  _customParams.clear();
  _responseProcessors.clear();

}

void _configureGroup(Group group, ClassMirror clazz, Injector injector, 
                     List<int> chainIdxByLevel, {String urlPrefix}) {

  var className = MirrorSystem.getName(clazz.qualifiedName);
  _logger.info("Found group: $className");

  InstanceMirror instance = null;
  try {
    instance = reflect(injector.get(clazz.reflectedType));
  } catch(e) {
    _logger.severe("Failed to get $className", e);
    throw new SetupException(className, "Failed to create a instance of the group $className");
  }

  String prefix = group.urlPrefix;
  if (urlPrefix != null) {
    prefix = _joinUrl(urlPrefix, prefix);
  }

  clazz.instanceMembers.values.forEach((MethodMirror method) {

    method.metadata.forEach((InstanceMirror metadata) {
      if (metadata.reflectee is Route) {
        
        Route route = metadata.reflectee as Route;

        _configureTarget(route, instance, method, urlPrefix: prefix);
      } else if (metadata.reflectee is Interceptor) {

        Interceptor interceptor = metadata.reflectee as Interceptor;
        
        chainIdxByLevel = new List.from(
            chainIdxByLevel.where((l) => l != null))
                ..add(interceptor.chainIdx);

        _configureInterceptor(interceptor, instance, method, 
            urlPrefix: prefix, chainIdxByLevel: chainIdxByLevel);
      } else if (metadata.reflectee is ErrorHandler) {
        
        ErrorHandler errorHandler = metadata.reflectee as ErrorHandler;
        
        _configureErrorHandler(errorHandler, instance, method, urlPrefix: prefix);
      }
    });

  });
}

void _configureInterceptor(Interceptor interceptor, ObjectMirror owner, 
                           MethodMirror handler, 
                           {String urlPrefix, List<int> chainIdxByLevel}) {

  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  
  var posParams = [];
  var namedParams = {};
  handler.parameters.forEach((ParameterMirror param) {
    bool hasProvider = false;
    if (!param.metadata.isEmpty) {
      var metadata = param.metadata[0];
      List<_ParamHandler> params = _customParams[ERROR_HANDLER];
      if (params != null) {
        _ParamHandler customParam = params.firstWhere((_ParamHandler p) => 
            metadata.reflectee.runtimeType == p.metadataType, orElse: () => null);
        if (customParam != null) {
          var paramName = MirrorSystem.getName(param.simpleName);
          var defaultValue = param.hasDefaultValue ? param.defaultValue : null;
          var value = customParam.parameterProvider(metadata.reflectee, paramName, request, _injector);
          if (value == null) {
            value = defaultValue;
          }
          if (param.isNamed) {
            namedParams[param.simpleName] = value;
          } else {
            posParams.add(value);
          }
          
          hasProvider = true;
        }
      }
    }
    if (!hasProvider) {
      try {
        if (param.isNamed) {
          namedParams[param.simpleName] = _injector.get(param.type.reflectedType);
        } else {
          posParams.add(_injector.get(param.type.reflectedType));
        }
      } catch (_) {
        var paramName = MirrorSystem.getName(param.simpleName);
        throw new SetupException(handlerName, "Invalid parameter: Can't inject $paramName");
      }
    }
  });

  var caller = () {

    _logger.finer("Invoking interceptor: $handlerName");
    owner.invoke(handler.simpleName, posParams, namedParams);

  };
  
  String url = interceptor.urlPattern;
  if (urlPrefix != null) {
    url = _joinUrl(urlPrefix, url);
  }
  
  if (chainIdxByLevel == null) {
    chainIdxByLevel = [];
  }

  var name = MirrorSystem.getName(handler.qualifiedName);
  _interceptors.add(new _Interceptor(new RegExp(url), name,
                                     chainIdxByLevel, interceptor.parseRequestBody, 
                                     caller));

  _logger.info("Configured interceptor for ${interceptor.urlPattern} : $handlerName");
}

void _configureErrorHandler(ErrorHandler errorHandler, 
                            ObjectMirror owner, MethodMirror handler, 
                            {String urlPrefix}) {

  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  
  var posParams = [];
  var namedParams = {};
  handler.parameters.forEach((ParameterMirror param) {
    bool hasProvider = false;
    if (!param.metadata.isEmpty) {
      var metadata = param.metadata[0];
      List<_ParamHandler> params = _customParams[ERROR_HANDLER];
      if (params != null) {
        _ParamHandler customParam = params.firstWhere((_ParamHandler p) => 
            metadata.reflectee.runtimeType == p.metadataType, orElse: () => null);
        if (customParam != null) {
          var paramName = MirrorSystem.getName(param.simpleName);
          var defaultValue = param.hasDefaultValue ? param.defaultValue : null;
          var value = customParam.parameterProvider(metadata.reflectee, paramName, request, _injector);
          if (value == null) {
            value = defaultValue;
          }
          if (param.isNamed) {
            namedParams[param.simpleName] = value;
          } else {
            posParams.add(value);
          }
          
          hasProvider = true;
        }
      }
    }
    
    if (!hasProvider) {
      try {
        if (param.isNamed) {
          namedParams[param.simpleName] = _injector.get(param.type.reflectedType);
        } else {
          posParams.add(_injector.get(param.type.reflectedType));
        }
      } catch (_) {
        var paramName = MirrorSystem.getName(param.simpleName);
        throw new SetupException(handlerName, "Invalid parameter: Can't inject $paramName");
      }
    }
  });

  var caller = () {

    _logger.finer("Invoking error handler: $handlerName");
    owner.invoke(handler.simpleName, posParams, namedParams);

  };

  var name = MirrorSystem.getName(handler.qualifiedName);
  List<_ErrorHandler> handlers = _errorHandlers[errorHandler.statusCode];
  if (handlers == null) {
    handlers = [];
    _errorHandlers[errorHandler.statusCode] = handlers;
  }
  String url = errorHandler.urlPattern;
  if (url != null && urlPrefix != null) {
    url = _joinUrl(urlPrefix, url);
  }
  
  RegExp pattern = url != null ? 
      new RegExp(url) : null;
  handlers.add(new _ErrorHandler(errorHandler.statusCode, 
      pattern, name, caller));

  var urlInfo = url != null ? " - $url" : "";
  _logger.info("Configured error handler for status ${errorHandler.statusCode} $urlInfo : $handlerName");
}

void _configureTarget(Route route, ObjectMirror owner, 
                      MethodMirror handler, {String urlPrefix}) {

  var paramProcessors = _buildParamProcesors(handler);
  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  
  var responseProcessors = [];
  handler.metadata.forEach((m) {
    var proc = _responseProcessors.firstWhere((p) => 
        m.reflectee.runtimeType == p.metadataType, orElse: () => null);
    if (proc != null) {
      responseProcessors.add(
          new _ResponseHandlerInstance(m.reflectee, handlerName, proc.processor));
    }
  });

  var caller = (UrlMatch match, Request request) {
    
    _logger.finer("Preparing to execute target: $handlerName");

    return new Future(() {

      var httpResp = request.response;
      var pathParams = match.parameters;
      
      var posParams = [];
      var namedParams = {};
      paramProcessors.processors.forEach((f) {
        var targetParam = f(pathParams, request);
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
      return _writeResponse(respValue, httpResp, route.responseType, 
                            abortIfChainInterrupted: true,
                            processors: responseProcessors);

    });    

  };
  
  String url = route.urlTemplate;
  if (urlPrefix != null) {
    url = _joinUrl(urlPrefix, url);
  }

  _targets.add(new _Target(new UrlTemplate(url), handlerName, caller, route, paramProcessors.bodyType));

  _logger.info("Configured target for ${url} : $handlerName");
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

        return (Map urlParams, Request request) {
          return new _TargetParam(request.body, name);
        };

      } else if (metadata.reflectee is QueryParam) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var convertFunc = _buildConvertFunction(param.type);
        var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;
        var queryParamName = (metadata.reflectee as QueryParam).name;
        if (queryParamName == null) {
          queryParamName = paramName;
        }

        return (Map urlParams, Request request) {
          var value = request.queryParams[queryParamName];
          try {
            value = convertFunc(value, defaultValue);
          } catch(e) {
            throw new RequestException(handlerName, "Invalid value for $paramName: $value");
          }
          return new _TargetParam(value, name);
        };
      } else if (metadata.reflectee is Attr) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;
        var attrName = (metadata.reflectee as Attr).name;
        if (attrName == null) {
          attrName = paramName;
        }
        
        return (Map urlParams, Request request) {
          var value = request.attributes[attrName];
          if (value == null) {
            value = defaultValue;
          }
          return new _TargetParam(value, name);
        };
      } else if (metadata.reflectee is Inject) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var value;
        try {
          value = _injector.get(param.type.reflectedType);
        } catch (e) {
          throw new SetupException(handlerName, "Invalid parameter: Can't inject $paramName");
        }
        var targetParam = new _TargetParam(value, name);
        return (Map urlParams, Request request) =>
            targetParam;
        
      } else {
        List<_ParamHandler> params = _customParams[ROUTE];
        if (params != null) {
          _ParamHandler customParam = params.firstWhere((_ParamHandler p) => 
              metadata.reflectee.runtimeType == p.metadataType, orElse: () => null);
          if (customParam != null) {
            var paramName = MirrorSystem.getName(paramSymbol);
            var defaultValue = param.hasDefaultValue ? 
                param.defaultValue.reflectee : null;
            var type = param.type.hasReflectedType ? param.type.reflectedType : null;
            return (Map urlParams, Request request) {
              var value = customParam.parameterProvider(metadata.reflectee, 
                  type, handlerName, paramName, request, _injector);
              if (value == null) {
                value = defaultValue;
              }
              return new _TargetParam(value, name);
            };
          }
        }
      }
    }

    var convertFunc = _buildConvertFunction(param.type);
    var paramName = MirrorSystem.getName(paramSymbol);
    var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;

    return (Map urlParams, Request request) {
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

String _joinUrl(String prefix, String url) {
  if (prefix.endsWith("/")) {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  
  if (!url.startsWith("/")) {
    url = "$prefix/$url";
  } else {
    url = "$prefix$url";
  }
  
  return url;
}