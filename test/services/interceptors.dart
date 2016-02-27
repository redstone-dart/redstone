library interceptors;

import "dart:async";

import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

@Route("/target")
String target() => "target_executed";

@Interceptor("/target", chainIdx: 0)
Future<shelf.Response> interceptor1() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new shelf.Response.ok(
      "before_interceptor1|$responseString|after_interceptor1");
}

@Interceptor("/target", chainIdx: 1)
Future<shelf.Response> interceptor2() async {
  var response = await chain.next();
  var responseString = await response.readAsString();
  return new shelf.Response.ok(
      "before_interceptor2|$responseString|after_interceptor2");
}

@Route("/interrupt")
String target2() => "not_reached";

@Interceptor("/interrupt")
Future<shelf.Response> interceptor3() =>
    chain.createResponse(401, responseValue: "chain_interrupted");

@Route("/redirect")
String target3() => "not_reached";

@Interceptor("/redirect")
shelf.Response interceptor4() => redirect("/new_path");

@Route("/abort")
String target4() => "not_reached";

@Interceptor("/abort")
Future<shelf.Response> interceptor5() => abort(401);

@Route("/basicauth_data")
String target6() => "basic_auth";

@Interceptor("/basicauth_data")
Future<shelf.Response> interceptor7() {
  var authInfo = request.parseAuthorizationHeader();
  if (authInfo.username == "Aladdin" && authInfo.password == "open sesame") {
    return chain.next();
  } else {
    return abort(403);
  }
}

@Interceptor("/parse_body", parseRequestBody: true)
Future<shelf.Response> interceptor8(@Body(JSON) Map form) {
  return chain.next();
}

@Route("/parse_body")
String target8() => "target_executed";
