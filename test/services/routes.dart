library routes;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/path/:subpath*")
String mainRoute() => "main_route";

@Route("/path/subpath")
String subRoute() => "sub_route";

@Route("/path2/:param*")
String mainRouteWithParam(String param) => param;

@Route("/handler_by_method")
String getHandler() => "get_handler";

@Route("/handler_by_method", methods: const [POST])
String postHandler() => "post_handler";

@Route("/change_status_code", statusCode: 201)
String changeStatusCode() => "response";

@Group("/group")
class ServiceGroup {
  @DefaultRoute()
  String defaultRoute() => "default_route";

  @DefaultRoute(pathSuffix: ".json")
  String defaultRouteJson() => "default_route_json";

  @DefaultRoute(methods: const [POST])
  String defaultRoutePost() => "default_route_post";

  @Interceptor("/path(/.*)?")
  Future<shelf.Response> interceptor() async {
    await chain.next();
    var resp = await response.readAsString();
    return new shelf.Response.ok("interceptor $resp");
  }

  @Route("/path/:subpath*")
  String mainRoute() => "main_route";

  @Route("/path/subpath")
  String subRoute() => "sub_route";

  @Route("/change_status_code", statusCode: 201)
  String changeStatusCode() => "response";
}

abstract class Info {
  @Route("/info")
  String info();
}

abstract class Version {
  @Route("/version")
  String version();
}

@Group("/mixed")
class MixedServiceGroup extends ServiceGroup with Info, Version {
  String info() => "info";
  String version() => "version";

  @Route("/change_status_code", statusCode: 202)
  String changeStatusCode() => "mixed response";
}
