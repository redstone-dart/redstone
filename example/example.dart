library test_lib;

import 'package:bloodless/server.dart' as app;

@app.Route("/")
helloWorld() => "Hello, World!";

@app.Route("/user/:username")
getUsername(String username) => ">> $username";

@app.Interceptor(r'/user/.+')
doge() {
  app.request.response.write("wow! such user!\n\n");
  app.chain.next().then((_) {
    app.request.response.write("\n\nso smart!");
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