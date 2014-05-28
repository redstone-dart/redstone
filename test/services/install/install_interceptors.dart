library install_interceptors;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Install(chainIdx: 1)
import 'install_interceptors_level_1.dart';

@app.Interceptor("/.+")
interceptor() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
      new shelf.Response.ok("interceptor_1 $resp"));
  });
}
