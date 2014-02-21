library test_lib;

import 'dart:async';

import 'package:bloodless/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

@app.Route("/teste/:username")
helloUser(String username) => {"user": username};

main() {

  app.start().then((_) => print("Server started!"));
  
}