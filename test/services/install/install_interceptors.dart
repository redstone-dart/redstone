library install_interceptors;

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'dart:async';
@Install(chainIdx: 1)
import 'install_interceptors_level_1.dart';

@Interceptor("/.+")
Future<shelf.Response> interceptor() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new shelf.Response.ok("interceptor_1 $responseString");
}
