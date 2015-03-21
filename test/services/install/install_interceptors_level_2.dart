library install_interceptors_level_2;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Interceptor("/.+")
interceptor() async {
  await chain.next();
  return response
      .readAsString()
      .then((resp) => new shelf.Response.ok("interceptor_3 $resp"));
}
