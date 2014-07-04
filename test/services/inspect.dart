library inspect;

import 'package:redstone/server.dart' as app;

//test metadata access

@app.Route("/route1")
route1() => "route1";

@app.Route("/route2")
route2() => "route2";

@app.Interceptor("/interceptor")
interceptor() => app.chain.next();

@app.ErrorHandler(333)
errorHandler() => null;

@app.Group("/group")
class GroupPluginTest {

  @app.Route("/route1")
  route1() => "route1";
  
  @app.Route("/route2")
  route2() => "route2";
  
  @app.Interceptor("/interceptor")
  interceptor() => app.chain.next();
  
  @app.ErrorHandler(333)
  errorHandler() => null;

}