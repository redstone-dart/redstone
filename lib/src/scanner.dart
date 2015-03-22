library redstone.src.scanner;

import 'dart:mirrors';

import 'server_metadata.dart';
import 'metadata.dart';

/// A Scanner is responsible for retrieving
/// the metadata information of an application
class Scanner {
  final List<Symbol> libraries;

  List<LibraryMetadata> _rootLibraries;
  List<LibraryMirror> _loadedLibraries;

  List<RouteMetadata> _routes;
  List<InterceptorMetadata> _interceptors;
  List<ErrorHandlerMetadata> _errorHandlers;
  List<GroupMetadata> _groups;

  Set<Symbol> _libCache = new Set();

  Scanner([this.libraries]);

  ServerMetadata scan() {
    _rootLibraries = [];
    _loadedLibraries = [];
    _routes = [];
    _interceptors = [];
    _errorHandlers = [];
    _groups = [];

    var mirrorSystem = currentMirrorSystem();
    Iterable<LibraryMirror> mirrors;

    if (libraries != null) {
      mirrors = libraries.map((s) => mirrorSystem.findLibrary(s));
    } else {
      mirrors = [mirrorSystem.isolate.rootLibrary];
    }

    mirrors.forEach((mirror) {
      LibraryMetadata lib = _scanLibrary(mirror);
      if (lib != null) {
        _rootLibraries.add(lib);
      }
    });

    return new ServerMetadata(_rootLibraries, _loadedLibraries, _routes,
        _interceptors, _errorHandlers, _groups);
  }

  LibraryMetadata _scanLibrary(LibraryMirror mirror, [Install conf]) {
    var dependencies = [];
    mirror.libraryDependencies
        .where((d) => d.isImport &&
            _libCache.add(d.targetLibrary.simpleName) &&
            !blacklistSet.contains(d.targetLibrary.simpleName))
        .forEach((d) {
      Install conf = null;
      var metadata = [];
      for (InstanceMirror m in d.metadata) {
        metadata.add(m.reflectee);
        if (m.reflectee is Ignore) {
          return;
        } else if (m.reflectee is Install) {
          conf = m.reflectee;
          break;
        }
      }

      LibraryMetadata lib = _scanLibrary(d.targetLibrary, conf);
      if (lib != null) {
        dependencies.add(lib);
      }
    });

    LibraryMetadata lib = new LibraryMetadata(conf, mirror,
        mirror.metadata.map((m) => m.reflectee).toList(growable: false),
        dependencies);

    _loadHandlers(lib);

    _loadedLibraries.add(mirror);

    return lib;
  }

  void _loadHandlers(LibraryMetadata lib) {
    for (DeclarationMirror declaration in lib.mirror.declarations.values) {
      if (declaration is MethodMirror) {
        declaration.metadata.map((m) => m.reflectee).forEach((conf) {
          if (conf is Route) {
            lib.routes.add(_loadRoute(lib, declaration, conf));
          } else if (conf is Interceptor) {
            lib.interceptors.add(_loadInterceptor(lib, declaration, conf));
          } else if (conf is ErrorHandler) {
            lib.errorHandlers.add(_loadErrorHandlers(lib, declaration, conf));
          }
        });
      } else if (declaration is ClassMirror) {
        declaration.metadata.map((m) => m.reflectee).forEach((conf) {
          if (conf is Group) {
            lib.groups.add(_loadGroup(lib, declaration, conf));
          }
        });
      }
    }

    _routes.addAll(lib.routes);
    _interceptors.addAll(lib.interceptors);
    _errorHandlers.addAll(lib.errorHandlers);
    _groups.addAll(lib.groups);
  }

  RouteMetadata _loadRoute(
      LibraryMetadata lib, MethodMirror mirror, Route conf) {
    var metadata =
        mirror.metadata.map((m) => m.reflectee).toList(growable: false);

    return new RouteMetadata(lib, conf, mirror, metadata);
  }

  InterceptorMetadata _loadInterceptor(
      LibraryMetadata lib, MethodMirror mirror, Interceptor conf) {
    var metadata =
        mirror.metadata.map((m) => m.reflectee).toList(growable: false);

    return new InterceptorMetadata(lib, conf, mirror, metadata);
  }

  ErrorHandlerMetadata _loadErrorHandlers(
      LibraryMetadata lib, MethodMirror mirror, ErrorHandler conf) {
    var metadata =
        mirror.metadata.map((m) => m.reflectee).toList(growable: false);

    return new ErrorHandlerMetadata(lib, conf, mirror, metadata);
  }

  GroupMetadata _loadGroup(
      LibraryMetadata lib, ClassMirror mirror, Group conf) {
    var metadata =
        mirror.metadata.map((m) => m.reflectee).toList(growable: false);

    var defaultRoutes = [];
    var routes = [];
    var interceptors = [];
    var errorHandlers = [];

    for (DeclarationMirror declaration in mirror.declarations.values) {
      if (declaration is MethodMirror) {
        declaration.metadata.map((m) => m.reflectee).forEach((conf) {
          if (conf is DefaultRoute) {
            defaultRoutes.add(_loadDefaultRoutes(lib, declaration, conf));
          } else if (conf is Route) {
            routes.add(_loadRoute(lib, declaration, conf));
          } else if (conf is Interceptor) {
            interceptors.add(_loadInterceptor(lib, declaration, conf));
          } else if (conf is ErrorHandler) {
            errorHandlers.add(_loadErrorHandlers(lib, declaration, conf));
          }
        });
      }
    }

    return new GroupMetadata(lib, conf, mirror, metadata, defaultRoutes, routes,
        interceptors, errorHandlers);
  }

  DefaultRouteMetadata _loadDefaultRoutes(
      LibraryMetadata lib, MethodMirror mirror, DefaultRoute conf) {
    var metadata =
        mirror.metadata.map((m) => m.reflectee).toList(growable: false);

    return new DefaultRouteMetadata(lib, conf, mirror, metadata);
  }
}

//do not scan the following libraries
const BLACKLIST = const [
  #dart.core,
  #dart.async,
  #dart.collection,
  #dart.convert,
  #dart.html,
  #dart.indexed_db,
  #dart.io,
  #dart.isolate,
  #dart.js,
  #dart.math,
  #dart.mirrors,
  #dart.svg,
  #dart.typed_data,
  #dart.web_audio,
  #dart.web_gl,
  #dart.web_sql
];

Set<Symbol> blacklistSet = new Set<Symbol>.from(BLACKLIST);
