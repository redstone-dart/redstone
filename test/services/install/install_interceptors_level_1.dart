library install_interceptors_level_1;

import 'dart:async';

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart';

@Interceptor("/.+", chainIdx: 0)
Future<Response> interceptor() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new Response.ok("interceptor_2 $responseString");
}

@Interceptor("/.+", chainIdx: 2)
Future<Response> interceptor2() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new Response.ok("interceptor_4 $responseString");
}
