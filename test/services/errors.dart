library errors;

import "dart:async";

import 'package:bloodless/server.dart' as app;

@app.Route("/wrong_method", methods: const [app.POST])
wrongMethod() => "this route accepts only POST requests";

@app.Route("/wrong_type", methods: const [app.POST])
wrongType(@app.Body(app.JSON) Map json) => "This route accepts only JSON content";

@app.Route("/wrong_value/:value")
wrongParam(int value) => value;

@app.Route("/route_error")
serverError() => throw "The client must receive a 500 status code";

@app.Route("/async_route_error")
asyncServerError() => new Future(() => 
    throw "The client must receive a 500 status code");

@app.Route("/interceptor_error")
targetInterceptorError() => "not_reached";

@app.Interceptor("/interceptor_error")
interceptorError() => throw "The client must receive a 500 status code";

@app.Route("/async_interceptor_error")
targetAsyncInterceptorError() => "target_executed ";

@app.Interceptor("/async_interceptor_error")
asyncInterceptorError() {
  app.chain.next(() => new Future(() => throw "The client must receive a 500 status code"));
}

@app.ErrorHandler(404)
notFoundHandler() => app.request.response.write("not_found");

@app.ErrorHandler(500)
serverErrorHandler() => app.request.response.write("server_error");