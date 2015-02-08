library errors;

import "dart:async";

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/wrong_method", methods: const [POST])
wrongMethod() => "this route accepts only POST requests";

@Route("/wrong_type", methods: const [POST])
wrongType(@Body(JSON) Map json) => "This route accepts only JSON content";

@Route("/wrong_value/:value")
wrongParam(int value) => value;

@Route("/route_error")
serverError() => throw "The client must receive a 500 status code";

@Route("/async_route_error")
asyncServerError() => new Future(() => 
    throw "The client must receive a 500 status code");

@Route("/interceptor_error")
targetInterceptorError() => "not_reached";

@Interceptor("/interceptor_error")
interceptorError() => throw "The client must receive a 500 status code";

@Route("/async_interceptor_error")
targetAsyncInterceptorError() => "target_executed ";

@Interceptor("/async_interceptor_error")
asyncInterceptorError() async {
  await chain.next();
  throw "The client must receive a 500 status code";
}

@ErrorHandler(404)
notFoundHandler() => new shelf.Response.notFound("not_found");

@ErrorHandler(500)
serverErrorHandler() => 
    new shelf.Response.internalServerError(body: "server_error");

@Route("/sub_handler")
subHandler() => throw "server_error";

@ErrorHandler(500, urlPattern: "/sub_handler?")
subErrorHandler() => new shelf.Response.internalServerError(
    body: "${chain.error} sub_error_handler");

@Route("/error_response")
errorResponse() => throw new ErrorResponse(400, "error_response");

@ErrorHandler(400, urlPattern: "/error_response")
handleErrorResponse() async {
  String resp = await response.readAsString();
  return new shelf.Response(response.statusCode, 
      body: "handling: $resp",
      headers: response.headers);
}