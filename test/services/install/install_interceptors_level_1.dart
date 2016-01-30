library install_interceptors_level_1;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Install(chainIdx: 1)
import 'install_interceptors_level_2.dart';

@Interceptor("/.+", chainIdx: 0)
Future<shelf.Response> interceptor() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new shelf.Response.ok("interceptor_2 $responseString");
}

@Interceptor("/.+", chainIdx: 2)
Future<shelf.Response> interceptor2() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new shelf.Response.ok("interceptor_4 $responseString");
}
