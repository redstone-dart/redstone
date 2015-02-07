library http_test;

import "package:redstone/redstone.dart";
import "package:shelf/shelf.dart" as shelf;

@Route("/")
helloWorld() => "Hello, World!";

@Route("/user/:username")
getUsername(String username) => ">> $username";

@Interceptor(r"/user/.+")
doge() async {
  await chain.next();
  String user = await response.readAsString();
  return new shelf.Response.ok("wow! such user!\n\n$user\n\nso smart!");
}

@Group("/group")
class ServicesGroup {
  @Route("/json", methods: const[POST])
  echoJson(@Body(JSON) Map json) => json;

  @Route("/form", methods: const[POST])
  echoFormAsJson(@Body(FORM) Map form) => form;
}

main() {
  setupConsoleLog();
  // Start a server on default host / port
  start();
}