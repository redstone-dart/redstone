part of redstone_server;

var _intType = reflectClass(int);
var _doubleType = reflectClass(double);
var _boolType = reflectClass(bool);
var _stringType = reflectClass(String);
var _dynamicType = reflectType(dynamic);
var _voidType = currentMirrorSystem().voidType;

final Map<String, _Target> _targetsCache = {};

final List<_Target> _targets = [];
final List<_Interceptor> _interceptors = [];
final Map<int, List<_ErrorHandler>> _errorHandlers = {};

final List<RedstonePlugin> _plugins = [];
final List<Module> _modules = [];

final Map<String, List<_ParamHandler>> _customParams = {};
final List<_ResponseHandler> _responseProcessors = [];

shelf.Pipeline _initHandler = null;
shelf.Handler _finalHandler = null;

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
  _RequestHandler handler;
  
  String handlerName;
  Route route;
  final Set<String> bodyTypes = new Set();

  _Target(this.urlTemplate, this.handlerName, 
          this.handler, this.route, [String bodyType = "*"]) {
    bodyTypes.add(bodyType);
  }
  
  UrlMatch match(Uri uri) {
    UrlMatch match = urlTemplate.match(uri.path);
    if (match != null) {
      if (route.matchSubPaths) {
        if (uri.path.endsWith("/") || match.tail.startsWith("/")) {
          return match;
        }
      } else {
        if (match.tail.isEmpty) {
          return match;
        }
      }
    }
    
    if (match != null && match.tail.isEmpty) {
      return match;
    }
    return null;
  }

  Future handleRequest(Request req, [UrlMatch urlMatch]) {
    if (urlMatch == null) {
      urlMatch = match(req.url);
      if (urlMatch == null) {
        return null;
      }
    }

    return handler(urlMatch, req);
  }
}

class _TargetWrapper extends _Target {
  
  final List<_Target> _innerTargets = [];
  
  _TargetWrapper(_Target target) :
    super(target.urlTemplate, target.handlerName, target.handler, target.route) {
    bodyTypes.addAll(target.bodyTypes);
    
    _innerTargets.add(target);
  }
  
  void addTarget(_Target target) {
    bodyTypes.addAll(target.bodyTypes);
    _innerTargets.add(target);
  }
  
  void build() {
    _buildHandlerName();
    _buildRoute();
    _buildRequestHandler();
  }
  
  void _buildHandlerName() {
    var str = new StringBuffer("Target(${_innerTargets[0].handlerName}");
    _innerTargets.sublist(1).forEach((t) {
      str.write(", ${t.handlerName}");
    });
    str.write(")");
    handlerName = str.toString();
  }
  
  void _buildRoute() {
    Set<String> methods = new Set();
    bool allowMultipartRequest = false;
    bool matchSubPaths = false;
    
    _innerTargets.forEach((t) {
      methods.addAll(t.route.methods);
      if (t.route.allowMultipartRequest) {
        allowMultipartRequest = true;
      }
      if (t.route.matchSubPaths) {
        matchSubPaths = true;
      }
    });
    
    route = new Route.conf(route.urlTemplate, methods: new List.from(methods), 
        allowMultipartRequest: allowMultipartRequest, matchSubPaths: matchSubPaths);
    
  }
  
  void _buildRequestHandler() {
    handler = (UrlMatch match, Request req) {
      
      return new Future(() {
        _Target target = _innerTargets.firstWhere((t) => 
            t.route.methods.contains(req.method));  
        
        return _verifyRequest(target, req)
            .then((_) => target.handleRequest(req));
      });
      
    };
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
  
  const _ParamHandler.defaultProvider() : 
      metadataType = null,
      parameterProvider = const _DefaultParamProvider();
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
  
  
  _ManagerImpl manager = new _ManagerImpl();
  
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
  
  routes.forEach((r) => _configureTarget(manager.serverMetadata, r.metadata, 
      r.lib.def, r.method, urlPrefix: r.lib.conf.urlPrefix));
  errors.forEach((e) => _configureErrorHandler(manager.serverMetadata, 
      e.metadata, e.lib.def, e.method, urlPrefix: e.lib.conf.urlPrefix));
  
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
    
    _configureInterceptor(manager.serverMetadata, i.metadata, 
          i.lib.def, i.method, 
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
    
    _configureGroup(manager.serverMetadata, g.metadata, 
          g.clazz, _injector, 
          levelHist, urlPrefix: g.lib.conf.urlPrefix);
  });
  
  
  //install plugins
  manager._installPlugins();
  
  _targets.addAll(_targetsCache.values.map((t) {
    if (t is _TargetWrapper) {
      t.build();
    }
    return t;
  }));
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

  _targetsCache.clear();
  _targets.clear();
  _interceptors.clear();
  _errorHandlers.clear();
  
  _modules.clear();
  _plugins.clear();
  _customParams.clear();
  _responseProcessors.clear();
  
  _initHandler = null;
  _finalHandler = null;

}

void _configureGroup(_ServerMetadataImpl serverMetadata,
                     Group group, ClassMirror clazz, Injector injector, 
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
  
  var groupMetadata = serverMetadata._addGroup(group, clazz);

  clazz.instanceMembers.values.forEach((MethodMirror method) {

    method.metadata.forEach((InstanceMirror metadata) {
      if (metadata.reflectee is DefaultRoute) {
        
        DefaultRoute info = metadata.reflectee as DefaultRoute;
        var url = prefix;
        if (info.pathSuffix != null) {
          url = prefix + info.pathSuffix;
        }
        Route route = new Route.conf(url, methods: info.methods, 
            responseType: info.responseType, 
            allowMultipartRequest: info.allowMultipartRequest,
            matchSubPaths: info.matchSubPaths);
        
        _configureTarget(groupMetadata, route, instance, method);
      } else if (metadata.reflectee is Route) {
        
        Route route = metadata.reflectee as Route;

        _configureTarget(groupMetadata, route, instance, method, urlPrefix: prefix);
      } else if (metadata.reflectee is Interceptor) {

        Interceptor interceptor = metadata.reflectee as Interceptor;
        
        chainIdxByLevel = new List.from(
            chainIdxByLevel.where((l) => l != null))
                ..add(interceptor.chainIdx);

        _configureInterceptor(groupMetadata, interceptor, instance, method, 
            urlPrefix: prefix, chainIdxByLevel: chainIdxByLevel);
      } else if (metadata.reflectee is ErrorHandler) {
        
        ErrorHandler errorHandler = metadata.reflectee as ErrorHandler;
        
        _configureErrorHandler(groupMetadata, errorHandler, 
                               instance, method, urlPrefix: prefix);
      }
    });

  });
}

void _configureInterceptor(_ServerMetadataImpl serverMetadata,
                           Interceptor interceptor, ObjectMirror owner, 
                           MethodMirror handler, 
                           {String urlPrefix, List<int> chainIdxByLevel}) {

  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  
  var posParams;
  var namedParams;

  var caller = () {
    if (posParams == null) {
      posParams = [];
      namedParams = {};
      
      handler.parameters.forEach((ParameterMirror param) {
        bool hasProvider = false;
        if (!param.metadata.isEmpty) {
          var metadata = param.metadata[0];
          List<_ParamHandler> params = _customParams[INTERCEPTOR];
          if (params != null) {
            _ParamHandler customParam = params.firstWhere((_ParamHandler p) => 
                metadata.reflectee.runtimeType == p.metadataType, orElse: () => null);
            if (customParam != null) {
              var paramName = MirrorSystem.getName(param.simpleName);
              var type = param.type.hasReflectedType ? param.type.reflectedType : null;
              var defaultValue = param.hasDefaultValue ? param.defaultValue : null;
              var value = customParam.parameterProvider(metadata.reflectee, 
                  type, handlerName, paramName, request, _injector);
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
    }
    
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
  
  serverMetadata._addInterceptor(interceptor, handler);

  _logger.info("Configured interceptor for $url : $handlerName");
}

void _configureErrorHandler(_ServerMetadataImpl serverMetadata,
                            ErrorHandler errorHandler, 
                            ObjectMirror owner, MethodMirror handler, 
                            {String urlPrefix}) {

  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  
  var posParams;
  var namedParams;

  var caller = () {
    if (posParams == null) {
      posParams = [];
      namedParams = {};
      
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
              var type = param.type.hasReflectedType ? param.type.reflectedType : null;
              var defaultValue = param.hasDefaultValue ? param.defaultValue : null;
              var value = customParam.parameterProvider(metadata.reflectee, 
                  type, handlerName, paramName, request, _injector);
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
    }

    _logger.finer("Invoking error handler: $handlerName");
    var value = owner.invoke(handler.simpleName, posParams, namedParams);
    if (value.reflectee is Future) {
      return value.reflectee.then((r) {
        if (r is shelf.Response) {
          response = r;
        }
      });
    } else if (value.reflectee is shelf.Response) {
      response = value.reflectee;
    }
    
    return new Future.value();
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
  
  serverMetadata._addErrorHandler(errorHandler, handler);

  var urlInfo = url != null ? " - $url" : "";
  _logger.info("Configured error handler for status ${errorHandler.statusCode} $urlInfo : $handlerName");
}

void _configureTarget(_ServerMetadataImpl serverMetadata, 
                      Route route, ObjectMirror owner, 
                      MethodMirror handler, {String urlPrefix}) {

  var paramProcessors = _buildParamProcesors(handler);
  var handlerName = MirrorSystem.getName(handler.qualifiedName);
  
  var responseProcessors = null;

  var caller = (UrlMatch match, Request request) {
    
    if (responseProcessors == null) {
      responseProcessors = [];
      handler.metadata.forEach((m) {
        var proc = _responseProcessors.firstWhere((p) => 
            m.reflectee.runtimeType == p.metadataType, orElse: () => null);
        if (proc != null) {
          responseProcessors.add(
              new _ResponseHandlerInstance(m.reflectee, handlerName, proc.processor));
        }
      });
    }
    
    _logger.finer("Preparing to execute target: $handlerName");

    return new Future(() {

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

      var errorResponse;
      var respValue;
      _logger.finer("Invoking target $handlerName");
      InstanceMirror resp;
      try {
        resp = owner.invoke(handler.simpleName, posParams, namedParams);
        
        if (resp.type == _voidType) {
          return null;
        }

        respValue = resp.reflectee;
        if (respValue is ErrorResponse) {
          errorResponse = respValue;
        }
      } on ErrorResponse catch(err) {
        errorResponse = respValue = err;
      }

      _logger.finer("Writing response for target $handlerName");
      return _writeResponse(respValue, route.responseType, 
        abortIfChainInterrupted: true,
        processors: responseProcessors)
          .then((_) {
             if (errorResponse != null) {
               chain.error = errorResponse.error;
               return _handleError("ErrorResponse returned by $handlerName", 
                   errorResponse.error, req: request, 
                   statusCode: errorResponse.statusCode,
                   logLevel: Level.FINER,
                   printErrorPage: false);
             }
          });

    });    

  };
  
  String url = route.urlTemplate;
  if (urlPrefix != null) {
    url = _joinUrl(urlPrefix, url);
  }

  UrlTemplate urlTemplate = new UrlTemplate(url);
  _Target target;
  if (paramProcessors.bodyType == null) {
    target = new _Target(urlTemplate, handlerName, caller, route);
  } else {
    target = new _Target(urlTemplate, handlerName, caller, route, 
        paramProcessors.bodyType);
  }
  
  String key = urlTemplate.toString();
  _Target currentTarget = _targetsCache[key];
  if (currentTarget != null) {
    if (currentTarget is! _TargetWrapper) {
      currentTarget = new _TargetWrapper(currentTarget);
    }
    (currentTarget as _TargetWrapper).addTarget(target);
    _targetsCache[key] = currentTarget;
  } else {
    _targetsCache[key] = target;
  }
  
  serverMetadata._addRoute(route, handler);

  _logger.info("Configured target for ${url} ${route.methods}: $handlerName");
}

_ParamProcessors _buildParamProcesors(MethodMirror handler) {

  String bodyType = null;

  List processors = handler.parameters.map((ParameterMirror param) {
    var handlerName = MirrorSystem.getName(handler.qualifiedName);
    var paramSymbol = param.simpleName;
    var name = param.isNamed ? paramSymbol : null;

    if (!param.metadata.isEmpty) {
      var metadata = param.metadata[0].reflectee;

      if (metadata is Body) {

        var body = metadata as Body;
        if (bodyType != null) {
          throw new SetupException(handlerName, "Invalid parameters: Only one parameter can be annotated with @Body");
        }
        bodyType = body.type;
        var valueHandler;
        if (param.type.reflectedType == QueryMap) {
          valueHandler = (value) => new QueryMap(value);
        } else {
          valueHandler = (value) => value;
        }

        return (Map urlParams, Request request) {
          return new _TargetParam(valueHandler(request.body), name);
        };

      } else if (metadata is QueryParam) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var convertFunc = _buildConvertFunction(param.type);
        var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;
        var queryParamName = (metadata as QueryParam).name;
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
      } else if (metadata is Attr) {
        var paramName = MirrorSystem.getName(paramSymbol);
        var defaultValue = param.hasDefaultValue ? param.defaultValue.reflectee : null;
        var attrName = (metadata as Attr).name;
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
      } else if (metadata is Inject) {
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
        
        var paramName = MirrorSystem.getName(paramSymbol);
        var defaultValue = param.hasDefaultValue ? 
            param.defaultValue.reflectee : null;
        var type = param.type.hasReflectedType ? param.type.reflectedType : null;
        
        var customParam;
          
        return (Map urlParams, Request request) {
          if (customParam == null) {
            var params = _customParams[ROUTE];
            if (params != null) {
              customParam = params.firstWhere((_ParamHandler p) => 
                metadata.runtimeType == p.metadataType, 
                orElse: () => const _ParamHandler.defaultProvider());
            } else {
              customParam = const _ParamHandler.defaultProvider();
            }
          }
          
          var value = customParam.parameterProvider(metadata, 
              type, handlerName, paramName, request, _injector);
          if (value == null) {
            value = defaultValue;
          }
          return new _TargetParam(value, name);
        };
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
    
  }).toList(growable: false);
  
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