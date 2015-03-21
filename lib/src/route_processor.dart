library redstone.src.route_processor;

import 'dart:io';
import 'dart:async';
import 'dart:mirrors';

import 'package:shelf/shelf.dart' as shelf;
import 'package:di/di.dart';

import 'request.dart';
import 'request_context.dart';
import 'request_parser.dart';
import 'server_metadata.dart';
import 'parameters_processor.dart';
import 'metadata.dart';
import 'response_writer.dart';
import 'dynamic_map.dart';
import 'constants.dart';

class RouteProcessor implements Function {
  final RequestTargetMetadata routeMetadata;
  final Injector injector;

  ObjectMirror owner;
  DynamicRoute dynamicRoute;

  Function _invoker;

  BodyType _bodyType;
  ParametersProcessor _paramsProcessor;

  RouteProcessor(this.routeMetadata, this.injector, [this.owner]) {
    if (owner == null) {
      owner = routeMetadata.library.mirror;
    }

    _paramsProcessor = new ParametersProcessor(routeMetadata.name,
        routeMetadata.mirror.parameters, injector,
        routeMetadata.parameterProviders, _urlHandler);

    _paramsProcessor
      ..addDefaultMetadataHandlers()
      ..addMetadataHandler(QueryParam, _queryHandler)
      ..addMetadataHandler(Body, _bodyHandler)
      ..build();

    _createInvoker();
  }

  RouteProcessor.fromDynamicRoute(
      this.routeMetadata, this.injector, this.dynamicRoute);

  Future<shelf.Response> call(RequestParser request) async {
    _verifyRequest(request);

    await request.parseBody();

    var response;

    if (dynamicRoute != null) {
      response = await dynamicRoute(injector, request);
    } else {
      response = await _invoker(injector, request);
    }

    if (response is ErrorResponse) {
      throw response;
    }

    return writeResponse(routeMetadata.name, response,
        statusCode: routeMetadata.conf.statusCode,
        responseType: routeMetadata.conf.responseType,
        injector: injector,
        responseProcessors: routeMetadata.responseProcessors);
  }

  void _createInvoker() {
    _invoker = (Injector injector, Request req) async {
      var positionalArgs = [];
      var namedArgs = {};

      await _paramsProcessor(req, positionalArgs, namedArgs);

      try {
        return await owner.invoke(routeMetadata.mirror.simpleName,
            positionalArgs, namedArgs).reflectee;
      } on ErrorResponse catch (e) {
        return e;
      }
    };

    routeMetadata.wrappers.reversed.forEach((w) {
      var f = _invoker;
      _invoker = (Injector injector, Request req) =>
          w.wrapper(w.metadata, injector, req, f);
    });
  }

  void _verifyRequest(Request req) {

    //verify method
    if (!routeMetadata.conf.methods.contains(req.method)) {
      throw new RequestException(routeMetadata.name,
          "${req.method} method not allowed", HttpStatus.METHOD_NOT_ALLOWED);
    }

    //verify multipart
    if (req.isMultipart && !routeMetadata.conf.allowMultipartRequest) {
      throw new RequestException(
          routeMetadata.name, "multipart request not allowed");
    }

    //verify body type
    if (_bodyType != null && _bodyType != req.bodyType) {
      throw new RequestException(
          routeMetadata.name, "${req.bodyType} data not supported");
    }
  }

  ArgHandler _bodyHandler(String handlerName, Injector injector,
      Object metadata, ParameterMirror mirror) {
    if (_bodyType != null) {
      throw new SetupException(handlerName,
          "Invalid parameters: Only one parameter can be annotated with @Body");
    }

    var body = (metadata as Body);
    if (body.type == null) {
      throw new SetupException(
          handlerName, "Invalid parameters: @Body.type can't be null");
    }
    _bodyType = body.type;

    if (mirror.type.reflectedType == DynamicMap) {
      return (Request req, _) => new DynamicMap({}..addAll(req.body));
    } else {
      return (Request req, _) => req.body;
    }
  }

  ArgHandler _queryHandler(String handlerName, Injector injector,
      Object metadata, ParameterMirror mirror) {
    var name = MirrorSystem.getName(mirror.simpleName);
    var queryParam = (metadata as QueryParam);
    var key = queryParam.name != null ? queryParam.name : name;
    if (mirror.type == listType) {
      return (Request req, Converter converter) {
        List<String> args = req.queryParameters[key];
        if (args == null) {
          return null;
        }
        return args
            .map((v) => convertValue(converter, name, v, handlerName))
            .toList();
      };
    } else {
      return (Request req, Converter converter) {
        List<String> args = req.queryParameters[key];
        if (args == null || args.isEmpty) {
          return null;
        }
        return converter(args[0]);
      };
    }
  }

  ArgHandler _urlHandler(String handlerName, Injector injector, Object metadata,
      ParameterMirror mirror) {
    var name = MirrorSystem.getName(mirror.simpleName);
    return (Request req, Converter converter) =>
        convertValue(converter, name, req.urlParameters[name], handlerName);
  }
}
