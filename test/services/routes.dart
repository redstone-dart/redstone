library routes;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/path", matchSubPaths: true)
mainRoute() => "main_route";

@app.Route("/path/subpath")
subRoute() => "sub_route";

@app.Group("/group")
class Group {
  
  @app.Interceptor("/path(/.*)?")
  interceptor() {
    app.chain.next(() {
      return app.response.readAsString().then((String resp) =>
        app.response = new shelf.Response.ok("interceptor $resp"));
    });
  }
  
  @app.Route("/path", matchSubPaths: true)
  mainRoute() => "main_route";

  @app.Route("/path/subpath")
  subRoute() => "sub_route";
  
}