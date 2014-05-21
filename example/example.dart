library test_lib;

import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart' as shelf;

@app.Route("/")
helloWorld() => "Hello, World!";

@app.Route("/user/:username")
getUsername(String username) => ">> $username";

@app.Interceptor(r'/user/.+')
doge() {
  app.chain.next(() {
    return app.response.readAsString().then((user) {
      app.response = new shelf.Response.ok("wow! such user!\n\n$user\n\nso smart!");
    });
  });
}

@app.Group("/group")
class Group {

  @app.Route("/json", methods: const[app.POST])
  echoJson(@app.Body(app.JSON) Map json) => json;

  @app.Route("/form", methods: const[app.POST])
  echoFormAsJson(@app.Body(app.FORM) Map form) => form;

}

main() {

  app.setupConsoleLog();
  app.start();
  
}