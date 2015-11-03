library https_test;

import "dart:io";
import "package:path/path.dart";
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
  @Route("/json", methods: const [POST])
  echoJson(@Body(JSON) Map json) => json;

  @Route("/form", methods: const [POST])
  echoFormAsJson(@Body(FORM) Map form) => form;
}

main() {
  String localFile(path) => Platform.script.resolve(path).toFilePath();

  SecurityContext serverContext = new SecurityContext()
    ..useCertificateChain(localFile('certificates/server_chain.pem'))
    ..usePrivateKey(localFile('certificates/server_key.pem'),
        password: 'dartdart');

  var secureOptions = {#certificateName: "CN=RedStone", #context: serverContext};

  setupConsoleLog();
  // Start a secure server (https) on default host / port using the RedStone certificate
  start(secureOptions: secureOptions);
}
