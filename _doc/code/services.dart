library services;

import 'package:redstone/redstone.dart' as app;

@app.Route("/user/:username")
helloUser(String username) => "hello, $username";