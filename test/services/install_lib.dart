library install_lib;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Install(urlPrefix: "/prefix")
import 'install/install_path.dart';
@app.Install(urlPrefix: "/chain", chainIdx: 1)
import 'install/install_interceptors.dart';
@app.Ignore()
import 'install/ignore.dart';

@app.Interceptor("/chain/.+")
interceptorRoot() {
  app.chain.next(() {
    return app.response.readAsString().then((resp) =>
        app.response = new shelf.Response.ok("root $resp"));
  });
}

@app.Route("/chain/route")
route() => "target ";
