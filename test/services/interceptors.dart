library interceptors;

import "dart:async";

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/target")
target() => "target_executed";

@Interceptor("/target", chainIdx: 0)
interceptor1() async {
  await chain.next();
  return response.readAsString().then((resp) =>
    new shelf.Response.ok(
        "before_interceptor1|$resp|after_interceptor1"));
}

@Interceptor("/target", chainIdx: 1)
interceptor2() async {
  await chain.next();
  return response.readAsString().then((resp) =>
    new shelf.Response.ok(
        "before_interceptor2|$resp|after_interceptor2"));
}

@Route("/interrupt")
target2() => "not_reached";

@Interceptor("/interrupt")
interceptor3() {
  return chain.interrupt(statusCode: 401, responseValue: "chain_interrupted");
}

@Route("/redirect")
target3() => "not_reached";

@Interceptor("/redirect")
interceptor4() => redirect("/new_path");

@Route("/abort")
target4() => "not_reached";

@Interceptor("/abort")
interceptor5() => abort(401);

@Route("/basicauth_data")
target6() => "basic_auth";

@Interceptor("/basicauth_data")
interceptor7() { 
   var authInfo = request.parseAuthorizationHeader();
   if (authInfo.username == "Aladdin" && authInfo.password == "open sesame") {
     return chain.next();
   } else {
     return abort(403);
   }
}

@Interceptor("/parse_body", parseRequestBody: true)
interceptor8() {
  return chain.next();
}

@Route("/parse_body")
target8() => "target_executed";


