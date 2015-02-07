library install_lib;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Install(urlPrefix: "/prefix")
import 'install/install_path.dart';
@Install(urlPrefix: "/chain", chainIdx: 1)
import 'install/install_interceptors.dart';
@Ignore()
import 'install/ignore.dart';

@Interceptor("/chain/.+")
interceptorRoot() async {
  await chain.next();
  return response.readAsString().then((resp) =>
      new shelf.Response.ok("root $resp"));
}

@Route("/chain/route")
route() => "target ";
