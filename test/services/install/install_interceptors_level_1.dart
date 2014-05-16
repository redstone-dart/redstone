library install_interceptors_level_1;

import 'package:redstone/server.dart' as app;

@app.Install(chainIdx: 1)
import 'install_interceptors_level_2.dart';

@app.Interceptor("/.+", chainIdx: 0)
interceptor() {
  app.request.response.write("interceptor_2 ");
  app.chain.next();
}

@app.Interceptor("/.+", chainIdx: 2)
interceptor2() {
  app.request.response.write("interceptor_4 ");
  app.chain.next();
}

