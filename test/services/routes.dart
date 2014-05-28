library routes;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/path", matchSubPaths: true)
mainRoute() => "main_route";

@app.Route("/path/subpath")
subRoute() => "sub_route";

@app.Route("/handler_by_method")
getHandler() => "get_handler";

@app.Route("/handler_by_method", methods: const[app.POST])
postHandler() => "post_handler";

@app.Group("/group")
class Group {
  
  @app.DefaultRoute()
  defaultRoute() => "default_route";
  
  @app.DefaultRoute(pathSuffix: ".json")
  defaultRouteJson() => "default_route_json";
  
  @app.DefaultRoute(methods: const[app.POST])
  defaultRoutePost() => "default_route_post";
  
  @app.Interceptor("/path(/.*)?")
  interceptor() {
    app.chain.next(() {
      return app.response.readAsString().then((String resp) =>
        new shelf.Response.ok("interceptor $resp"));
    });
  }
  
  @app.Route("/path", matchSubPaths: true)
  mainRoute() => "main_route";

  @app.Route("/path/subpath")
  subRoute() => "sub_route";
  
}