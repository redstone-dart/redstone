library routes;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/path/:subpath*")
mainRoute() => "main_route";

@Route("/path/subpath")
subRoute() => "sub_route";

@Route("/path2/:param*")
mainRouteWithParam(String param) => param;

@Route("/handler_by_method")
getHandler() => "get_handler";

@Route("/handler_by_method", methods: const [POST])
postHandler() => "post_handler";

@Route("/change_status_code", statusCode: 201)
changeStatusCode() => "response";

@Group("/group")
class ServiceGroup {
  @DefaultRoute()
  defaultRoute() => "default_route";

  @DefaultRoute(pathSuffix: ".json")
  defaultRouteJson() => "default_route_json";

  @DefaultRoute(methods: const [POST])
  defaultRoutePost() => "default_route_post";

  @Interceptor("/path(/.*)?")
  interceptor() async {
    await chain.next();
    var resp = await response.readAsString();
    return new shelf.Response.ok("interceptor $resp");
  }

  @Route("/path/:subpath*")
  mainRoute() => "main_route";

  @Route("/path/subpath")
  subRoute() => "sub_route";

  @Route("/change_status_code", statusCode: 201)
  changeStatusCode() => "response";
}
