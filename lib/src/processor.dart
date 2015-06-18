library redstone.src.processor;

import 'dart:async';
import 'dart:mirrors';

import 'package:di/di.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'metadata.dart';
import 'server_metadata.dart';
import 'server_context.dart';
import 'plugin.dart';
import 'route_processor.dart';
import 'request.dart';
import 'response_writer.dart';
import 'parameters_processor.dart';
import 'request_parser.dart';

/// An processor is responsible for creating
/// and managing handlers (routes, interceptors, error handlers
/// and groups). It's also responsible for plugins execution.
class Processor implements Manager {
  final ServerMetadata serverMetadata;
  final ShelfContext shelfContext;
  List<Module> modules;
  List<RedstonePlugin> plugins;

  Map<HandlerMetadata, RouteInvoker> _routeInvokers;
  Map<HandlerMetadata, InterceptorInvoker> _interceptorInvokers;
  Map<HandlerMetadata, ErrorHandlerInvoker> _errorHandlerInvokers;

  Injector _injector = null;

  Processor(this.serverMetadata, this.shelfContext,
      [this.modules, this.plugins]) {
    if (modules == null) {
      modules = [];
    }

    if (plugins == null) {
      plugins = [];
    }
  }

  Future<ServerContext> parse() async {
    _routeInvokers = {};
    _interceptorInvokers = {};
    _errorHandlerInvokers = {};

    _initializeInjector();

    await Future.forEach(plugins, (p) async {
      try {
        return await p(this);
      } catch (e) {
        throw new PluginException(e);
      }
    });

    serverMetadata.routes.forEach((RouteMetadata route) {
      if (!_routeInvokers.containsKey(route)) {
        _routeInvokers[route] = new RouteProcessor(route, _injector);
      }
    });

    serverMetadata.interceptors.forEach((InterceptorMetadata interceptor) {
      if (!_interceptorInvokers.containsKey(interceptor)) {
        _interceptorInvokers[interceptor] = _wrapInterceptor(interceptor);
      }
    });

    serverMetadata.errorHandlers.forEach((ErrorHandlerMetadata errorHandler) {
      if (!_errorHandlerInvokers.containsKey(errorHandler)) {
        _errorHandlerInvokers[errorHandler] = _wrapErrorHandler(errorHandler);
      }
    });

    serverMetadata.groups.forEach((GroupMetadata group) {
      var owner = reflect(_injector.get(group.mirror.reflectedType));

      group.defaultRoutes.forEach((DefaultRouteMetadata route) {
        _routeInvokers[route] = new RouteProcessor(route, _injector, owner);
      });

      group.routes.forEach((RouteMetadata route) {
        _routeInvokers[route] = new RouteProcessor(route, _injector, owner);
      });

      group.interceptors.forEach((InterceptorMetadata interceptor) {
        _interceptorInvokers[interceptor] =
            _wrapInterceptor(interceptor, owner);
      });

      group.errorHandlers.forEach((ErrorHandlerMetadata errorHandler) {
        _errorHandlerInvokers[errorHandler] =
            _wrapErrorHandler(errorHandler, owner);
      });
    });

    return new ServerContext(serverMetadata, _routeInvokers,
        _interceptorInvokers, _errorHandlerInvokers, shelfContext, _injector);
  }

  @override
  Injector get appInjector => _injector;

  @override
  Injector createInjector(List<Module> modules) =>
      new ModuleInjector(modules, appInjector);

  @override
  void set shelfHandler(shelf.Handler handler) {
    shelfContext.handler = handler;
  }

  @override
  shelf.Handler get shelfHandler => shelfContext.handler;

  @override
  void addRouteWrapper(Type metadataType, RouteWrapper wrapper,
      {bool includeGroups: false}) {
    _findHandlers(_getRoutes, metadataType, includeGroups).forEach((m) =>
        m.handler.wrappers.add(new RouteWrapperMetadata(wrapper, m.metadata)));
  }

  @override
  void addResponseProcessor(Type metadataType, ResponseProcessor processor,
      {bool includeGroups: false}) {
    _findHandlers(_getRoutes, metadataType, includeGroups).forEach(
        (m) => m.handler.responseProcessors
            .add(new ResponseProcessorMetadata(processor, m.metadata)));
  }

  @override
  void addParameterProvider(Type metadataType, ParamProvider parameterProvider,
      {List<HandlerType> handlerTypes: const [HandlerType.ROUTE]}) {
    handlerTypes.forEach((handlerType) {
      var f;
      switch (handlerType) {
        case HandlerType.ROUTE:
          f = _getRoutes;
          break;
        case HandlerType.INTERCEPTOR:
          f = _getInterceptors;
          break;
        case HandlerType.ERROR_HANDLER:
          f = _getErrorHandlers;
          break;
      }

      _findHandlersByParams(f, metadataType).forEach((m) =>
          m.handler.parameterProviders[metadataType] = parameterProvider);
    });
  }

  @override
  void addErrorHandler(
      ErrorHandler conf, String name, DynamicHandler errorHandler) {
    var invoker = _wrapDynamicErrorHandler(conf, name, errorHandler);

    var metadata = new ErrorHandlerMetadata(null, conf, null, [], name);
    _errorHandlerInvokers[metadata] = invoker;
    serverMetadata.errorHandlers.add(metadata);
  }

  @override
  void addInterceptor(
      Interceptor conf, String name, DynamicHandler interceptor) {
    var invoker = _wrapDynamicInterceptor(conf, interceptor);

    var metadata = new InterceptorMetadata(null, conf, null, [], name);
    _interceptorInvokers[metadata] = invoker;
    serverMetadata.interceptors.add(metadata);
  }

  @override
  void addRoute(Route conf, String name, DynamicRoute route) {
    var metadata = new RouteMetadata(null, conf, null, [], name);
    var invoker =
        new RouteProcessor.fromDynamicRoute(metadata, _injector, route);

    _routeInvokers[metadata] = invoker;
    serverMetadata.routes.add(metadata);
  }

  @override
  Iterable<AnnotatedType<MethodMirror>> findMethods(
      ClassMirror clazz, Type annotation) {
    var methods = [];
    clazz.instanceMembers.values.forEach((MethodMirror method) {
      var metadata = method.metadata.firstWhere(
          (m) => m.reflectee.runtimeType == annotation, orElse: () => null);

      if (metadata != null) {
        methods.add(new AnnotatedType(method, metadata.reflectee));
      }
    });

    return methods;
  }

  @override
  Iterable<AnnotatedType<ClassMirror>> findClasses(Type annotation) {
    var classes = [];
    _findDeclaredClasses().forEach((ClassMirror c) {
      var metadata = c.metadata.firstWhere(
          (m) => m.reflectee.runtimeType == annotation, orElse: () => null);

      if (metadata != null) {
        classes.add(new AnnotatedType(c, metadata.reflectee));
      }
    });

    return classes;
  }

  @override
  Iterable<AnnotatedType<MethodMirror>> findFunctions(Type annotation) {
    var functions = [];
    _findDeclaredFunctions().forEach((MethodMirror f) {
      var metadata = f.metadata.firstWhere(
          (m) => m.reflectee.runtimeType == annotation, orElse: () => null);

      if (metadata != null) {
        functions.add(new AnnotatedType(f, metadata.reflectee));
      }
    });

    return functions;
  }

  List<HandlerMetadata> _getRoutes(dynamic metadata) {
    if (metadata is ApplicationMetadata) {
      return []
        ..addAll(metadata.routes)
        ..addAll(metadata.groups.expand(_getRoutes));
    } else if (metadata is GroupMetadata) {
      return []
        ..addAll(metadata.defaultRoutes)
        ..addAll(metadata.routes);
    }
    return [];
  }

  List<HandlerMetadata> _getInterceptors(dynamic metadata) =>
      metadata.interceptors;

  List<HandlerMetadata> _getErrorHandlers(dynamic metadata) =>
      metadata.errorHandlers;

  List<_Match> _findHandlers(List<HandlerMetadata> getHandlers(metadata),
      Type metadataType, bool includeGroups) {
    var result = [];
    getHandlers(serverMetadata).forEach((h) => h.metadata.forEach((m) {
      if (m.runtimeType == metadataType) {
        result.add(new _Match(h, m));
      }
    }));

    if (includeGroups) {
      serverMetadata.groups.forEach((g) {
        g.metadata.forEach((m) {
          if (m.runtimeType == metadataType) {
            getHandlers(g).forEach((h) => result.add(new _Match(h, m)));
          }
        });
      });
    }

    return result;
  }

  List<_Match> _findHandlersByParams(
      List<HandlerMetadata> getHandlers(metadata), Type metadataType) {
    var result = [];
    getHandlers(serverMetadata).forEach(
        (h) => (h.mirror as MethodMirror).parameters.forEach((p) {
      p.metadata.map((m) => m.reflectee).forEach((m) {
        if (m.runtimeType == metadataType) {
          result.add(new _Match(h, m));
        }
      });
    }));

    serverMetadata.groups.forEach((g) {
      getHandlers(g).forEach((h) => (h.mirror as MethodMirror).parameters
          .forEach((p) {
        p.metadata.map((m) => m.reflectee).forEach((m) {
          if (m.runtimeType == metadataType) {
            result.add(new _Match(h, m));
          }
        });
      }));
    });

    return result;
  }

  void _initializeInjector() {
    var module = new Module();
    serverMetadata.groups.forEach((g) => module.bind(g.mirror.reflectedType));
    modules.add(module);
    _injector = new ModuleInjector(modules);
  }

  Iterable<MethodMirror> _findDeclaredFunctions() =>
      serverMetadata.loadedLibraries
          .expand((LibraryMirror ldef) => ldef.declarations.values)
          .where((d) => d is MethodMirror);

  Iterable<ClassMirror> _findDeclaredClasses() => serverMetadata.loadedLibraries
      .expand((LibraryMirror ldef) => ldef.declarations.values)
      .where((d) => d is ClassMirror);

  InterceptorInvoker _wrapInterceptor(InterceptorMetadata interceptor,
      [ObjectMirror owner]) {
    var paramsProcessor = new ParametersProcessor(interceptor.name,
        interceptor.mirror.parameters, _injector,
        interceptor.parameterProviders);

    paramsProcessor
      ..addDefaultMetadataHandlers()
      ..build();

    if (owner == null) {
      owner = interceptor.library.mirror;
    }

    return (RequestParser request) async {
      var positionalArgs = [];
      var namedArgs = {};

      await paramsProcessor(request, positionalArgs, namedArgs);

      if (interceptor.conf.parseRequestBody) {
        await request.parseBody();
      }

      return await owner.invoke(
          interceptor.mirror.simpleName, positionalArgs, namedArgs).reflectee;
    };
  }

  ErrorHandlerInvoker _wrapErrorHandler(ErrorHandlerMetadata errorHandler,
      [ObjectMirror owner]) {
    var paramsProcessor = new ParametersProcessor(errorHandler.name,
        errorHandler.mirror.parameters, _injector,
        errorHandler.parameterProviders);

    paramsProcessor
      ..addDefaultMetadataHandlers()
      ..build();

    if (owner == null) {
      owner = errorHandler.library.mirror;
    }

    return (Request request) async {
      var positionalArgs = [];
      var namedArgs = {};

      await paramsProcessor(request, positionalArgs, namedArgs);

      return await owner.invoke(
          errorHandler.mirror.simpleName, positionalArgs, namedArgs).reflectee;
    };
  }

  InterceptorInvoker _wrapDynamicInterceptor(
      Interceptor conf, DynamicHandler interceptor) {
    return (RequestParser request) async {
      if (conf.parseRequestBody) {
        await request.parseBody();
      }
      return await interceptor(_injector, request);
    };
  }

  ErrorHandlerInvoker _wrapDynamicErrorHandler(
      ErrorHandler conf, String handlerName, DynamicHandler errorHandler) {
    return (Request request) async {
      var response = await errorHandler(_injector, request);
      return writeResponse(handlerName, response, statusCode: conf.statusCode);
    };
  }
}

class _Match {
  HandlerMetadata handler;
  Object metadata;

  _Match(this.handler, this.metadata);
}
