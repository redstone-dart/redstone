library install_interceptors_level_2;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Interceptor("/.+")
interceptor() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) {
      app.response = new shelf.Response.ok("interceptor_3 $resp");
    });
  });
}