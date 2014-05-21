library install_interceptors_level_1;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Install(chainIdx: 1)
import 'install_interceptors_level_2.dart';

@app.Interceptor("/.+", chainIdx: 0)
interceptor() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
      new shelf.Response.ok("interceptor_2 $resp"));
  });
}

@app.Interceptor("/.+", chainIdx: 2)
interceptor2() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
      new shelf.Response.ok("interceptor_4 $resp"));
  });
}

