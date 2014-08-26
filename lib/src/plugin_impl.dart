part of redstone_server;

class _ManagerImpl implements Manager {
  
  final _ServerMetadataImpl serverMetadata = new _ServerMetadataImpl();

  Iterable<_Lib> _libs;

  void _installPlugins(Iterable<_Lib> libs) {
    _libs = libs;
    _plugins.forEach((p) {
      serverMetadata._commit();
      p(this);
    });
  }
    
  @override
  void addRoute(Route conf, String name, RouteHandler route, {String bodyType}) {
    var caller = (UrlMatch match, Request request) {
      _logger.finer("Preparing to execute target: $name");
      
      return new Future(() {
        _logger.finer("Invoking target $name");
        var respValue = route(match.parameters, _injector, request);

        _logger.finer("Writing response for target $name");
        return _writeResponse(respValue, 
            conf.responseType, abortIfChainInterrupted: true);
      });
  
    };
    
    var urlTemplate = new UrlTemplate(conf.urlTemplate);
    var target;
    
    if (bodyType == null) {
      target = new _Target(urlTemplate, name, caller, conf);
    } else {
      target = new _Target(urlTemplate, name, caller, conf, bodyType);
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
    
    var mirror = (reflect(route) as ClosureMirror).function;
    serverMetadata._addRoute(conf, mirror);
    
    _logger.info("Configured target for ${conf.urlTemplate} : $name");
  }
  
  @override
  void addInterceptor(Interceptor conf, String name, Handler interceptor) {
    var caller = () {

      _logger.finer("Invoking interceptor: $name");
      interceptor(_injector);
  
    };
    _interceptors.add(new _Interceptor(new RegExp(conf.urlPattern), name,
                                       [conf.chainIdx], conf.parseRequestBody, 
                                       caller));
    
    var mirror = (reflect(interceptor) as ClosureMirror).function;
    serverMetadata._addInterceptor(conf, mirror);
    
    _logger.info("Configured interceptor for ${conf.urlPattern} : $name");
  }
  
  @override
  void addErrorHandler(ErrorHandler conf, String name, Handler errorHandler) {
    var caller = () {

      _logger.finer("Invoking error handler: $name");
      var v = errorHandler(_injector);
      if (v is Future) {
        return v.then((r) {
          if (r is shelf.Response) {
            response = r;
          }
        });
      } else if (v is shelf.Response) {
        response = v;
      }
    };

    List<_ErrorHandler> handlers = _errorHandlers[conf.statusCode];
    if (handlers == null) {
      handlers = [];
      _errorHandlers[conf.statusCode] = handlers;
    }
    RegExp pattern = conf.urlPattern != null ? 
        new RegExp(conf.urlPattern) : null;
    handlers.add(new _ErrorHandler(conf.statusCode, 
        pattern, name, caller));
    
    var mirror = (reflect(errorHandler) as ClosureMirror).function;
    serverMetadata._addErrorHandler(conf, mirror);

    var url = conf.urlPattern != null ? " - " + conf.urlPattern : "";
    _logger.info("Configured error handler for status ${conf.statusCode} $url : $name");
  }
  
  @override
  void addParameterProvider(Type metadataType, ParamProvider parameterProvider, 
                            {List<String> handlerTypes: const [ROUTE]}) {
    handlerTypes.forEach((String type) {
      var paramProviders = _paramProviders[type];
      if (paramProviders == null) {
        paramProviders = {};
        _paramProviders[type] = paramProviders;
      }
      paramProviders[metadataType] = parameterProvider;
    });
  }
  
  @override
  void addResponseProcessor(Type metadataType, ResponseProcessor processor,
                            {bool includeGroups: false}) {
    _responseProcessors[metadataType] = processor;
    if (includeGroups) {
      _groupAnnotations.add(metadataType);
    }
  }
  
  @override
  void addRouteWrapper(Type metadataType, RouteWrapper wrapper, 
                       {bool includeGroups: false}) {
    _routeWrappers[metadataType] = wrapper;
    if (includeGroups) {
      _groupAnnotations.add(metadataType);
    }
  }

  @override
  shelf.Handler getShelfHandler() {
    return _defaultHandler;
  }

  @override
  void setShelfHandler(shelf.Handler handler) {
    _defaultHandler = handler;
  }

  @override
  Injector createInjector(List<Module> modules) {
    return new ModuleInjector(modules, _injector);
  }

  @override
  Object getInjector() => _injector;

  @override
  Iterable<AnnotatedType<MethodMirror>> findFunctions(Type annotation) {
    var functions = [];
    _findDeclaredFunctions().forEach((MethodMirror f) {

      var metadata = f.metadata.firstWhere((m) =>
        m.reflectee.runtimeType == annotation, orElse: () => null);

      if (metadata != null) {
        functions.add(new AnnotatedType(f, metadata.reflectee));
      }

    });

    return functions;
  }

  @override
  Iterable<AnnotatedType<ClassMirror>> findClasses(Type annotation) {
    var classes = [];
    _findDeclaredClasses().forEach((ClassMirror c) {

      var metadata = c.metadata.firstWhere((m) =>
        m.reflectee.runtimeType == annotation, orElse: () => null);

      if (metadata != null) {
        classes.add(new AnnotatedType(c, metadata.reflectee));
      }
    });

    return classes;
  }

  @override
  Iterable<AnnotatedType<MethodMirror>> findMethods(ClassMirror clazz, Type annotation) {
    var methods = [];
    _findDeclaredMethods(clazz).forEach((MethodMirror method) {

      var metadata = method.metadata.firstWhere((m) =>
        m.reflectee.runtimeType == annotation, orElse: () => null);

      if (metadata != null) {
        methods.add(new AnnotatedType(method, metadata.reflectee));
      }
    });

    return methods;
  }

  _findDeclaredFunctions() =>
    _libs.map((l) => l.def).expand((LibraryMirror ldef) =>
      ldef.declarations.values).where((d) => d is MethodMirror);

  _findDeclaredClasses() =>
    _libs.map((l) => l.def).expand((LibraryMirror ldef) =>
      ldef.declarations.values).where((d) => d is ClassMirror);

  _findDeclaredMethods(ClassMirror clazz) =>
    clazz.declarations.values.where((d) => d is MethodMirror);

}

class _ServerMetadataImpl implements ServerMetadata {
  
  final _errorHandlers = [];
  final _groups = [];
  final _interceptors = [];
  final _routes = [];
  
  var _errorHandlersView = const [];
  var _groupsView = const [];
  var _interceptorsView = const [];
  var _routesView = const [];
  
  List<RouteMetadata> get routes => _routesView;
  List<InterceptorMetadata> get interceptors => _interceptorsView;
  List<ErrorHandlerMetadata> get errorHandlers => _errorHandlersView;
  List<GroupMetadata> get groups => _groupsView;
  
  void _addRoute(Route route, MethodMirror mirror) {
    var metadata = mirror.metadata.map((m) => m.reflectee).toList(growable: false);
    _routes.add(new _RouteMetadataImpl(route, mirror, metadata));
  }
  
  void _addInterceptor(Interceptor interceptor, MethodMirror mirror) {
    var metadata = mirror.metadata.map((m) => m.reflectee).toList(growable: false);
    _interceptors.add(new _InterceptorMetadataImpl(interceptor, mirror, metadata));
  }
  
  void _addErrorHandler(ErrorHandler errorHandler, MethodMirror mirror) {
    var metadata = mirror.metadata.map((m) => m.reflectee).toList(growable: false);
    _errorHandlers.add(new _ErrorHandlerMetadataImpl(errorHandler, mirror, metadata));
  }
  
  _GroupMetadataImpl _addGroup(Group group, ClassMirror mirror) {
    var metadata = mirror.metadata.map((m) => m.reflectee).toList(growable: false);
    var groupMetadata = new _GroupMetadataImpl(group, mirror, metadata);
    _groups.add(groupMetadata);
    return groupMetadata;
  }
  
  void _commit() {
    _errorHandlersView = new List.from(_errorHandlers, growable: false);
    _interceptorsView = new List.from(_interceptors, growable: false);
    _routesView = new List.from(_routes, growable: false);
    _groupsView = new List.from(_groups, growable: false);
  }
}

class _HandlerMetadataImpl<T, M> implements HandlerMetadata<T, M> {
  
  final T conf;
  final M mirror;
  final List metadata;
  
  _HandlerMetadataImpl(this.conf, this.mirror, this.metadata);
  
}

final _specialChars = new RegExp(r'[\\()$^.+[\]{}|]');

class _RouteMetadataImpl extends _HandlerMetadataImpl<Route, MethodMirror> 
                         implements RouteMetadata {
  
  String _urlRegex;
  
  _RouteMetadataImpl(Route route, MethodMirror method, 
                     List metadata) :
      super(route, method, metadata);
  
  String get urlRegex {
    if (_urlRegex == null) {
      
      var template = conf.urlTemplate.
          replaceAllMapped(_specialChars, (m) => r'\' + m.group(0));

      var exp = new RegExp(r':(\w+)');
      StringBuffer sb = new StringBuffer('^');
      int start = 0;
      exp.allMatches(template).forEach((Match m) {
        var txt = template.substring(start, m.start);
        sb.write(txt);
        sb.write(r'([^/?]+)');
        start = m.end;
      });
      if (start != template.length) {
        var txt = template.substring(start, template.length);
        sb.write(txt);
      }
      _urlRegex = sb.toString();
    }
  
    return _urlRegex;  
  }
}

class _InterceptorMetadataImpl extends _HandlerMetadataImpl<Interceptor, MethodMirror>
                               implements InterceptorMetadata {
  
  _InterceptorMetadataImpl(Interceptor interceptor, MethodMirror method, List metadata) :
      super(interceptor, method, metadata);
  
}

class _ErrorHandlerMetadataImpl extends _HandlerMetadataImpl<ErrorHandler, MethodMirror>
                               implements ErrorHandlerMetadata {
  
  _ErrorHandlerMetadataImpl(ErrorHandler errorHandler, MethodMirror method, List metadata) :
      super(errorHandler, method, metadata);
  
}

class _GroupMetadataImpl extends _HandlerMetadataImpl<Group, ClassMirror> 
                         with _ServerMetadataImpl
                         implements GroupMetadata {
  
  _GroupMetadataImpl(Group group, ClassMirror method, List metadata) :
        super(group, method, metadata);
  
}

class _DefaultParamProvider {

  const _DefaultParamProvider();
  
  Object call(_, _1, _2, _3, _4, _5) {
    return null;
  }

}