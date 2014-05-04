library routes;

import 'package:bloodless/server.dart' as app;

@app.Route("/path", matchSubPaths: true)
mainRoute() => "main_route";

@app.Route("/path/subpath")
subRoute() => "sub_route";

@app.Group("/group")
class Group {
  
  @app.Interceptor("/path(/.*)?")
  interceptor() {
    app.request.response.write("interceptor ");
    app.chain.next();
  }
  
  @app.Route("/path", matchSubPaths: true)
  mainRoute() => "main_route";

  @app.Route("/path/subpath")
  subRoute() => "sub_route";
  
}