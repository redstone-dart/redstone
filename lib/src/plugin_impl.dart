part of redstone_server;

class _ManagerImpl implements Manager {
  
  void installPlugins() {
    _plugins.forEach((p) => p(this));
  }
    
  void addRoute(Route conf, String name, RouteHandler route, {String bodyType}) {
    var caller = (UrlMatch match, Request request) {
      _logger.finer("Preparing to execute target: $name");
      
      return new Future(() {
        _logger.finer("Invoking target $name");
        var respValue = route(match.parameters, _injector, request);

        _logger.finer("Writing response for target $name");
        return _writeResponse(respValue, request.response, 
            conf.responseType, abortIfChainInterrupted: true);
      });
  
    };
    
    _targets.add(new _Target(new UrlTemplate(conf.urlTemplate), name, 
                              caller, conf, bodyType));
    
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
    
    _logger.info("Configured interceptor for ${conf.urlPattern} : $name");
  }
  
  void addErrorHandler(ErrorHandler conf, String name, Handler errorHandler) {
    var caller = () {

      _logger.finer("Invoking error handler: $name");
      errorHandler(_injector);

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
}