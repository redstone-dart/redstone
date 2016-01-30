library https_test;

import "dart:io";
import "package:redstone/redstone.dart";
import "package:shelf/shelf.dart" as shelf;
import 'dart:async';

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
  String localFile(String path) => Platform.script.resolve(path).toFilePath();

  // Using certificates generated in
  // https://github.com/dart-lang/sdk/tree/master/tests/standalone/io/certificates
  SecurityContext serverContext = new SecurityContext()
    ..useCertificateChain(localFile('certificates/server_chain.pem'))
    ..usePrivateKey(localFile('certificates/server_key.pem'),
        password: 'dartdart');

  var secureOptions = <Symbol, dynamic>{
    #certificateName: "CN=RedStone",
    #context: serverContext
  };

  setupConsoleLog();
  // Start a secure server (https) on default host / port using the RedStone certificate
  start(secureOptions: secureOptions);
}
