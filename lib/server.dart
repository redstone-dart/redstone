library bloodless_server;

import 'dart:async';
import 'dart:io';
import 'dart:mirrors';

import 'package:route_hierarchical/url_matcher.dart';
import 'package:route_hierarchical/url_template.dart';


class Route {
  
  final String urlTemplate;
  
  final List<String> methods;

  final String response;

  const Route(String this.urlTemplate, 
              {this.methods: const ["GET", "POST"],
               this.response: "json"});
}

class Body {

  final String type;

  const Body(String this.type);

}

class FormElement {

  final String name;

  const FormElement(this.name);

}

class Interceptor {

  final String url;

  const Interceptor(String this.url);

}

class SetupException implements Exception {

  final String handler;
  final String message;

  SetupException(String this.handler, String this.message);

  String toString() => "SetupException: [$handler] $message";

}

get request => Zone.current[#request];


void start(httpServer) {

}

final List<_Target> targets = [];

typedef void _RequestHandler(UrlMatch match, HttpRequest request);

class _Target {
  
  final UrlTemplate urlTemplate;
  final _RequestHandler handler;
  final Route route;

  _Target(this.urlTemplate, this.handler, this.route);

  bool handleRequest(HttpRequest req) {

    return false; 
  }
}

void _scanHandlers() {
  currentMirrorSystem().libraries.values.forEach((LibraryMirror lib) {
    lib.topLevelMembers.values.forEach((MethodMirror method) {
      method.metadata.forEach((InstanceMirror metadata) {
        if (metadata.reflectee is Route) {
          _configureHandler(metadata.reflectee as Route, lib, method);
        }
      });
    });
  });
}

void _configureHandler(Route route, LibraryMirror lib, MethodMirror handler) {
  
  var paramsProcessors = new List.from(handler.parameters.map((ParameterMirror param) {
    if (!param.metadata.isEmpty) {
      var metadata = param.metadata[0];
      if (metadata.reflectee is Body) {

      } else if (metadata.reflectee is FormElement) {
        
      }
    }
  }));

  var caller = (UrlMatch match, HttpRequest request) {

  };
}

Map _getRequestAsJson(HttpRequest request) {

}

Map _getRequestAsForm(HttpRequest request) {

}

