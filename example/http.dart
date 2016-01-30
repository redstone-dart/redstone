library http_test;

import 'dart:async';
import "package:redstone/redstone.dart";
import "package:shelf/shelf.dart" as shelf;

@Route("/")
String helloWorld() => "Hello, World!";

@Route("/user/:username")
String getUsername(String username) => ">> $username";

@Interceptor(r"/user/.+")
Future<shelf.Response> doge() async {
  await chain.next();
  String user = await response.readAsString();
  return new shelf.Response.ok("wow! such user!\n\n$user\n\nso smart!");
}

@Group("/group")
class ServicesGroup {
  @Route("/json", methods: const [POST])
  Map echoJson(@Body(JSON) Map json) => json;

  @Route("/form", methods: const [POST])
  Map echoFormAsJson(@Body(FORM) Map form) => form;
}

void main() {
  setupConsoleLog();
  // Start a server on default host / port
  start();
}
