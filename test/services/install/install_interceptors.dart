library install_interceptors;

import 'package:redstone/server.dart' as app;

@app.Install(chainIdx: 1)
import 'install_interceptors_level_1.dart';

@app.Interceptor("/.+")
interceptor() {
  app.request.response.write("interceptor_1 ");
  app.chain.next();
}
