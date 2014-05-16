library install_lib;

import 'package:redstone/server.dart' as app;

@app.Install(urlPrefix: "/prefix")
import 'install/install_path.dart';
@app.Install(urlPrefix: "/chain", chainIdx: 1)
import 'install/install_interceptors.dart';
@app.Ignore()
import 'install/ignore.dart';

@app.Interceptor("/chain/.+")
interceptorRoot() {
  app.request.response.write("root ");
  app.chain.next();
}

@app.Route("/chain/route")
route() => app.request.response.write("target ");
