library install_interceptors_level_2;

import 'package:redstone/server.dart' as app;

@app.Interceptor("/.+")
interceptor() {
  app.request.response.write("interceptor_3 ");
  app.chain.next();
}