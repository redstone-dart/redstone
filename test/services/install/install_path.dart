library install_routes;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/route")
route() => "target_executed";

@Interceptor("/route")
interceptor() async {
  await chain.next();
  return response.readAsString().then((resp) =>
      new shelf.Response.ok("interceptor_executed $resp"));
}

@Route("/error")
error() => throw "error";

@ErrorHandler(500)
errorHandler() => new shelf.Response.internalServerError(body: "error_handler_executed");

@Group("/group")
class ServiceGroup {
  
  @Route("/route")
  route() => "target_executed";

  @Interceptor("/route")
  interceptor() async {
    await chain.next();
    return response.readAsString().then((resp) =>
      new shelf.Response.ok("interceptor_executed $resp"));
  }
  
}