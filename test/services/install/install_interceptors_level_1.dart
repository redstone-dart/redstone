library install_interceptors_level_1;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Install(chainIdx: 1)
import 'install_interceptors_level_2.dart';

@Interceptor("/.+", chainIdx: 0)
interceptor() async {
  await chain.next();
  return response.readAsString().then((resp) =>
    new shelf.Response.ok("interceptor_2 $resp"));

}

@Interceptor("/.+", chainIdx: 2)
interceptor2() async {
  await chain.next();
  return response.readAsString().then((resp) =>
    new shelf.Response.ok("interceptor_4 $resp"));
}

