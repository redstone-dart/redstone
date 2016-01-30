library install_lib;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Install(urlPrefix: "/prefix")
import 'install/install_path.dart';
@Install(urlPrefix: "/chain", chainIdx: 1)
import 'install/install_interceptors.dart';
@Ignore()
import 'install/ignore.dart';

@Interceptor("/chain/.+")
Future<shelf.Response> interceptorRoot() async {
  var response = await chain.next();
  String responseString = await response.readAsString();
  return new shelf.Response.ok("root $responseString");
}

@Route("/chain/route")
String route() => "target ";
