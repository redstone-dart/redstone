library redstone.src.server_metadata;

import 'dart:mirrors';

import 'package:di/di.dart';

import 'metadata.dart';
import 'request.dart';

/// A route programmatically created by a plugin.
typedef dynamic DynamicRoute(Injector injector, Request request);

/// A route wrapper created by a plugin.
typedef dynamic RouteWrapper(
    dynamic metadata, Injector injector, Request request, DynamicRoute route);

/// An interceptor or error handler, programmatically created by a plugin.
typedef dynamic DynamicHandler(Injector injector, Request request);

/// A parameter provider is a function that can create parameters
/// for routes, interceptors and error handlers.
///
/// It can be used, for example, to automatically validate
/// and parse the request body and arguments.
typedef dynamic ParamProvider(dynamic metadata, Type paramType,
    String handlerName, String paramName, Request request, Injector injector);

/// A response processor is a function which can transform values
/// returned by routes.
typedef dynamic ResponseProcessor(
    dynamic metadata, String handlerName, Object response, Injector injector);

/// Handler types
enum HandlerType { ROUTE, INTERCEPTOR, ERROR_HANDLER }

/// The base metadata class for handlers
class HandlerMetadata<T, M> {
  static int _idSource = 0;

  final int _id = _idSource++;

  String _name;

  /// An internal id, used by Redstone to track this handler
  int get id => _id;

  String get name => _name;

  final T conf;

  final M mirror;

  final List metadata;

  HandlerMetadata(this.conf, this.mirror, this.metadata, [this._name]) {
    if (_name == null) {
      _name = MirrorSystem.getName((mirror as DeclarationMirror).qualifiedName);
    }
  }

  operator ==(other) => other is HandlerMetadata && other.id == id;

  int get hashCode => id;
}

/// Library metadata information
class LibraryMetadata extends HandlerMetadata<Install, LibraryMirror>
    implements ApplicationMetadata {
  final List<LibraryMetadata> dependencies;

  final List<RouteMetadata> routes = [];

  final List<InterceptorMetadata> interceptors = [];

  final List<ErrorHandlerMetadata> errorHandlers = [];

  final List<GroupMetadata> groups = [];

  LibraryMetadata(
      Install conf, LibraryMirror mirror, List metadata, this.dependencies)
      : super(conf, mirror, metadata);
}

/// Provides access for installed routes, interceptors,
/// error handlers and groups that composes an application.
class ApplicationMetadata {

  /// Returns the installed routes.
  ///
  /// This list contains routes which are bound to top level
  /// functions. For routes that belongs to a group, see [groups];
  final List<RouteMetadata> routes;

  /// Returns the installed interceptors.
  ///
  /// This list contains interceptors which are bound to top level
  /// functions. For interceptors that belongs to a group, see [groups];
  final List<InterceptorMetadata> interceptors;

  /// Returns the installed error handlers.
  ///
  /// This list contains error handlers which are bound to top level
  /// functions. For error handlers that belongs to a group, see [groups];
  final List<ErrorHandlerMetadata> errorHandlers;

  /// Returns all installed groups.
  final List<GroupMetadata> groups;

  ApplicationMetadata(
      this.routes, this.interceptors, this.errorHandlers, this.groups);

  ApplicationMetadata.empty()
      : routes = [],
        interceptors = [],
        errorHandlers = [],
        groups = [];
}

/// Metadata of the current application
class ServerMetadata extends ApplicationMetadata {

  /// Returns the metadata of loaded libraries
  final List<LibraryMetadata> rootLibraries;

  /// Returns all libraries loaded by Redstone
  final List<LibraryMirror> loadedLibraries;

  ServerMetadata(this.rootLibraries, this.loadedLibraries,
      List<RouteMetadata> routes, List<InterceptorMetadata> interceptors,
      List<ErrorHandlerMetadata> errorHandlers, List<GroupMetadata> groups)
      : super(routes, interceptors, errorHandlers, groups);
}

abstract class RequestTargetMetadata
    implements HandlerMetadata<RequestTarget, MethodMirror> {
  List<RouteWrapperMetadata> get wrappers;

  Map<Type, ParamProvider> get parameterProviders;

  List<ResponseProcessorMetadata> get responseProcessors;

  LibraryMetadata get library;
}

/// Route metadata information
class RouteMetadata extends HandlerMetadata<Route, MethodMirror>
    implements RequestTargetMetadata {
  final List<RouteWrapperMetadata> wrappers = [];

  final Map<Type, ParamProvider> parameterProviders = {};

  final List<ResponseProcessorMetadata> responseProcessors = [];

  final LibraryMetadata library;

  RouteMetadata(this.library, Route conf, MethodMirror mirror, List metadata,
      [String name])
      : super(conf, mirror, metadata, name);
}

/// Default route metadata information
class DefaultRouteMetadata extends HandlerMetadata<DefaultRoute, MethodMirror>
    implements RequestTargetMetadata {
  final List<RouteWrapperMetadata> wrappers = [];

  final Map<Type, ParamProvider> parameterProviders = {};

  final List<ResponseProcessorMetadata> responseProcessors = [];

  final LibraryMetadata library;

  DefaultRouteMetadata(
      this.library, DefaultRoute conf, MethodMirror mirror, List metadata,
      [String name])
      : super(conf, mirror, metadata, name);
}

class RouteWrapperMetadata {
  final RouteWrapper wrapper;
  final Object metadata;

  RouteWrapperMetadata(this.wrapper, this.metadata);
}

class ResponseProcessorMetadata {
  final ResponseProcessor processor;
  final Object metadata;

  ResponseProcessorMetadata(this.processor, this.metadata);
}

/// Interceptor metadata information
class InterceptorMetadata extends HandlerMetadata<Interceptor, MethodMirror> {
  final Map<Type, ParamProvider> parameterProviders = {};

  final LibraryMetadata library;

  InterceptorMetadata(
      this.library, Interceptor conf, MethodMirror mirror, List metadata,
      [String name])
      : super(conf, mirror, metadata, name);
}

/// Error handler metadata information
class ErrorHandlerMetadata extends HandlerMetadata<ErrorHandler, MethodMirror> {
  final Map<Type, ParamProvider> parameterProviders = {};

  final LibraryMetadata library;

  ErrorHandlerMetadata(
      this.library, ErrorHandler conf, MethodMirror mirror, List metadata,
      [String name])
      : super(conf, mirror, metadata, name);
}

/// Group metadata information
class GroupMetadata extends HandlerMetadata<Group, ClassMirror> {
  final List<DefaultRouteMetadata> defaultRoutes;

  final List<RouteMetadata> routes;

  final List<InterceptorMetadata> interceptors;

  final List<ErrorHandlerMetadata> errorHandlers;

  final LibraryMetadata library;

  GroupMetadata(this.library, Group conf, ClassMirror mirror, List metadata,
      this.defaultRoutes, this.routes, this.interceptors, this.errorHandlers)
      : super(conf, mirror, metadata);
}

/// An [SetupException] can be thrown during
/// the setUp stage of Redstone
class SetupException implements Exception {
  final String handler;
  final String message;

  SetupException(this.handler, this.message);

  String toString() => "SetupException: [$handler] $message";
}
