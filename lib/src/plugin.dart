library redstone.src.plugin;

import 'dart:mirrors';

import 'package:di/di.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'metadata.dart';
import 'server_metadata.dart';

/// A plugin is a function which can dynamically add new features
/// to an application.
typedef dynamic RedstonePlugin(Manager manager);

/// Allows to programmatically create routes, interceptors, error handlers,
/// parameter providers and response processors.
///
/// To access a [Manager] instance, you need to create and register a [RedstonePlugin].
abstract class Manager {
  /// The server metadata, which contains all routes, interceptors,
  /// error handlers and groups that composes this application.
  ServerMetadata get serverMetadata;

  /// Create a new route.
  void addRoute(Route conf, String name, DynamicRoute route);

  /// Create a new interceptor.
  void addInterceptor(
      Interceptor conf, String name, DynamicHandler interceptor);

  /// Create a new error handler.
  void addErrorHandler(
      ErrorHandler conf, String name, DynamicHandler errorHandler);

  /// Create a new parameter provider.
  ///
  /// [metadataType] is the annotation type that will trigger the provider.
  /// [parameterProvider] is the function which will be invoked to create
  /// the parameter's value. [handlerTypes] are the handler types that can use
  /// this provider, and defaults to ROUTE.
  void addParameterProvider(Type metadataType, ParamProvider parameterProvider,
      {List<HandlerType> handlerTypes: const [HandlerType.route]});

  /// Create a new response processor.
  ///
  /// [metadataType] is the annotation type that will trigger the processor.
  /// [processor] is the function which will be invoked to transform the returned
  /// value. If [includeGroups] is true and the annotation is used on a group, then
  /// all group's routes will use the processor.
  void addResponseProcessor(Type metadataType, ResponseProcessor processor,
      {bool includeGroups: false});

  /// Create a new route wrapper.
  ///
  /// Wrap all routes that are annotated with [metadataType].
  /// If [includeGroups] is true and the annotation is used on a group,
  /// then all group's routes will be wrapped as well.
  ///
  /// Usage:
  ///
  ///      //wrap all routes annotated with @MyAnnotation()
  ///      manager.addRouteWrapper(MyAnnotation, (myAnnotation, pathSegments, injector, request, route) {
  ///
  ///        //here you can prevent the route from executing, or inspect and modify
  ///        //the returned value
  ///
  ///        return route(pathSegments, injector, request);
  ///
  ///      });
  void addRouteWrapper(Type metadataType, RouteWrapper wrapper,
      {bool includeGroups: false});

  /// Retrieve installed shelf handler
  shelf.Handler get shelfHandler;

  /// Set or replace the current installed shelf handler
  void set shelfHandler(shelf.Handler handler);

  /// Create a new DI injector restricted to the scope of this plugin.
  ///
  /// The returned injector will be a child of the application injector.
  Injector createInjector(List<Module> modules);

  /// Retrieve the application DI injector
  Injector get appInjector;

  /// Find all functions annotated with [annotation]
  Iterable<AnnotatedType<MethodMirror>> findFunctions(Type annotation);

  /// Find all classes annotated with [annotation]
  Iterable<AnnotatedType<ClassMirror>> findClasses(Type annotation);

  /// Find all methods of [clazz] that are annotated with [annotation]
  Iterable<AnnotatedType<MethodMirror>> findMethods(
      ClassMirror clazz, Type annotation);
}

class AnnotatedType<T> {
  final T mirror;
  final Object metadata;

  AnnotatedType(this.mirror, this.metadata);
}

class PluginException implements Exception {
  final dynamic causedBy;

  PluginException(this.causedBy);

  String toString() => "Failed to load plugin. Caused by: $causedBy";
}
