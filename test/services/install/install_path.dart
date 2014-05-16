library install_routes;

import 'package:redstone/server.dart' as app;

@app.Route("/route")
route() => "target_executed";

@app.Interceptor("/route")
interceptor() {
  app.request.response.write("interceptor_executed ");
  app.chain.next();
}

@app.Route("/error")
error() => throw "error";

@app.ErrorHandler(500)
errorHandler() => app.request.response.write("error_handler_executed");

@app.Group("/group")
class Group {
  
  @app.Route("/route")
  route() => "target_executed";

  @app.Interceptor("/route")
  interceptor() {
    app.request.response.write("interceptor_executed ");
    app.chain.next();
  }
  
}