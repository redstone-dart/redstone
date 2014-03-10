library interceptors;

import "dart:async";

import 'package:bloodless/server.dart' as app;

@app.Route("/target")
target() => "target_executed";

@app.Interceptor("/target", chainIdx: 0)
interceptor1() {
  new Future(() {
    app.request.response.write("before_interceptor1|");
    app.chain.next(() {
      return new Future(() => app.request.response.write("|after_interceptor1"));
    });
  });
}

@app.Interceptor("/target", chainIdx: 1)
interceptor2() {
  app.request.response.write("before_interceptor2|");
  app.chain.next(() {
    app.request.response.write("|after_interceptor2");
  });
}

@app.Route("/interrupt")
target2() => "not_reached";

@app.Interceptor("/interrupt")
interceptor3() {
  app.chain.interrupt(401, response: "chain_interrupted");
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


