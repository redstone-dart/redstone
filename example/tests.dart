library test_lib;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:bloodless/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

@app.Route("/teste/:username")
helloUser(String username) => {"user": username};

@app.Interceptor(r'/.*')
doge() {
  print("such interceptor!");
  app.chain.next().then((_) => print("much request!"));
}

@app.Group("/group")
class Group {

  @app.Route("/test")
  String testGroup() => "Group works!";

}

main() {

  app.setupConsoleLog(Level.INFO);
  app.start();
  
}