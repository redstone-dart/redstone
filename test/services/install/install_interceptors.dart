library install_interceptors;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Install(chainIdx: 1)
import 'install_interceptors_level_1.dart';

@Interceptor("/.+")
interceptor() async {
  await chain.next();
  return response
      .readAsString()
      .then((resp) => new shelf.Response.ok("interceptor_1 $resp"));
}
