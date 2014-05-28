library interceptors;

import "dart:async";

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/target")
target() => "target_executed";

@app.Interceptor("/target", chainIdx: 0)
interceptor1() {
  new Future(() {
    app.chain.next(() {
      return app.response.readAsString().then((resp) =>
        new shelf.Response.ok(
            "before_interceptor1|$resp|after_interceptor1"));
    });
  });
}

@app.Interceptor("/target", chainIdx: 1)
interceptor2() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
      new shelf.Response.ok(
          "before_interceptor2|$resp|after_interceptor2"));
  });
}

@app.Route("/interrupt")
target2() => "not_reached";

@app.Interceptor("/interrupt")
interceptor3() {
  app.chain.interrupt(statusCode: 401, responseValue: "chain_interrupted");
}

@app.Route("/redirect")
target3() => "not_reached";

@app.Interceptor("/redirect")
interceptor4() {
  new Future(() {
    app.redirect("/new_path");
  });
}

@app.Route("/abort")
target4() => "not_reached";

@app.Interceptor("/abort")
interceptor5() {
  new Future(() {
    app.abort(401);
  });
}

@app.Route("/basicauth")
target5() => "basic_auth";

@app.Interceptor("/basicauth")
interceptor6() { 
   if (app.authenticateBasic('Aladdin', 'open sesame', realm: 'Redstone')) {
     app.chain.next();
   } else {
     app.chain.interrupt();
   }
}

@app.Route("/basicauth_data")
target6() => "basic_auth";

@app.Interceptor("/basicauth_data")
interceptor7() { 
   var authInfo = app.parseAuthorizationHeader();
   if (authInfo.username == "Aladdin" && authInfo.password == "open sesame") {
     app.chain.next();
   } else {
     app.abort(403);
   }
}


