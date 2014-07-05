part of redstone_server;

class _ManagerImpl implements Manager {
  
  final _ServerMetadataImpl serverMetadata = new _ServerMetadataImpl();
  
  void _installPlugins() {
    _plugins.forEach((p) {
      serverMetadata._commit();
      p(this);
    });
  }
    
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
  
  void addParameterProvider(Type metadataType, ParamProvider parameterProvider, 
                            {List<String> handlerTypes: const [ROUTE]}) {
    _ParamHandler param = new _ParamHandler(metadataType, parameterProvider);
    handlerTypes.forEach((String type) {
      List<_ParamHandler> params = _customParams[type];
      if (params == null) {
        params = [];
        _customParams[type] = params;
      }
      params.add(param);
    });
  }
  
  void addResponseProcessor(Type metadataType, ResponseProcessor processor) {
    _ResponseHandler proc = new _ResponseHandler(metadataType, processor);
    _responseProcessors.add(proc);
  }
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

class _HandlerMetadataImpl<T, M> implements HandlerMetadata {
  
  final T conf;
  final M mirror;
  final List metadata;
  
  _HandlerMetadataImpl(this.conf, this.mirror, this.metadata);
  
}

class _RouteMetadataImpl extends _HandlerMetadataImpl<Route, MethodMirror> 
                         implements RouteMetadata {
  
  _RouteMetadataImpl(Route route, MethodMirror method, List metadata) :
      super(route, method, metadata);
  
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