library install_routes;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/route")
route() => "target_executed";

@app.Interceptor("/route")
interceptor() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
        new shelf.Response.ok("interceptor_executed $resp"));
  });
}

@app.Route("/error")
error() => throw "error";

@app.ErrorHandler(500)
errorHandler() => new shelf.Response.internalServerError(body: "error_handler_executed");

@app.Group("/group")
class Group {
  
  @app.Route("/route")
  route() => "target_executed";

  @app.Interceptor("/route")
  interceptor() {
    app.chain.next(() {
      return app.response.readAsString().then((resp) =>
        new shelf.Response.ok("interceptor_executed $resp"));
    });
  }
  
}