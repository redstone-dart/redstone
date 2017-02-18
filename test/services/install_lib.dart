library install_lib;

import 'dart:async';

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart';

@Interceptor("/chain/.+")
Future<Response> interceptorRoot() async {
  var response = await chain.next();
  String responseString = await response.readAsString();
  return new Response.ok("root $responseString");
}

@Route("/chain/route")
String route() => "target ";
