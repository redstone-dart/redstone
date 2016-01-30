library redstone.src.server_context;

import 'dart:async';

import 'package:shelf/shelf.dart' as shelf;
import 'package:di/di.dart';

import 'request.dart';
import 'request_parser.dart';
import 'server_metadata.dart';

typedef Future<shelf.Response> RouteInvoker(RequestParser request);
typedef Future InterceptorInvoker(RequestParser request);
typedef Future ErrorHandlerInvoker(Request request);

class ServerContext {
  final ServerMetadata serverMetadata;
  final Map<HandlerMetadata, RouteInvoker> routeInvokers;
  final Map<HandlerMetadata, InterceptorInvoker> interceptorInvokers;
  final Map<HandlerMetadata, ErrorHandlerInvoker> errorHandlerInvokers;
  final ShelfContext shelfContext;
  final Injector injector;

  ServerContext(
      this.serverMetadata,
      this.routeInvokers,
      this.interceptorInvokers,
      this.errorHandlerInvokers,
      this.shelfContext,
      this.injector);
}

class ShelfContext {
  final List<shelf.Middleware> middlewares = [];
  shelf.Handler handler;
}
