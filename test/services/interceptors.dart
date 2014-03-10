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