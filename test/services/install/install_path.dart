library install_routes;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/route")
String route() => "target_executed";

@Interceptor("/route")
Future<shelf.Response> interceptor() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new shelf.Response.ok("interceptor_executed $responseString");
}

@Route("/error")
dynamic error() => throw "error";

@ErrorHandler(500)
shelf.Response errorHandler() =>
    new shelf.Response.internalServerError(body: "error_handler_executed");

@Group("/group")
class ServiceGroup {
  @Route("/route")
  String route() => "target_executed";

  @Interceptor("/route")
  Future<shelf.Response> interceptor() async {
    var response = await chain.next();
    var responseString = await response.readAsString();
    return new shelf.Response.ok("interceptor_executed $responseString");
  }
}
