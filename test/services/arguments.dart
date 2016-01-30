library arguments;

import 'package:redstone/redstone.dart';
import 'dart:async';
import 'package:shelf/shelf.dart' as shelf;

@Route("/args/:arg1/:arg2/:arg3")
Map pathArgs(String arg1, int arg2,
        [double arg3, String arg4, String arg5 = "arg5"]) =>
    {"arg1": arg1, "arg2": arg2, "arg3": arg3, "arg4": arg4, "arg5": arg5};

@Route("/named_args/:arg1/:arg2")
Map namedPathArgs(String arg1, {String arg2, String arg3, String arg4: "arg4"}) =>
    {"arg1": arg1, "arg2": arg2, "arg3": arg3, "arg4": arg4};

@Route("/query_args")
Map queryArgs(@QueryParam("arg1") String arg1, @QueryParam("arg2") int arg2,
    [@QueryParam() double arg3, @QueryParam("arg4") String arg4,
    @QueryParam("arg5") String arg5 = "arg5", String arg6,
    String arg7 = "arg7"]) => {
  "arg1": arg1,
  "arg2": arg2,
  "arg3": arg3,
  "arg4": arg4,
  "arg5": arg5,
  "arg6": arg6,
  "arg7": arg7
};

@Route("/query_args_with_num")
Map queryArgsWithNum(@QueryParam("arg1") num arg1,
                 @QueryParam("arg2") num arg2) => {
  "arg1": arg1,
  "arg2": arg2
};

@Route("/named_query_args")
Map namedQueryArgs(@QueryParam() String arg1, {@QueryParam() String arg2,
    @QueryParam("arg3") String arg3, @QueryParam("arg4") String arg4: "arg4",
    String arg5, String arg6: "arg6"}) => {
  "arg1": arg1,
  "arg2": arg2,
  "arg3": arg3,
  "arg4": arg4,
  "arg5": arg5,
  "arg6": arg6
};

@Route("/path_query_args/:arg")
Map pathAndQueryArgs(String arg, @QueryParam("arg") String qArg) =>
    {"arg": arg, "qArg": qArg};

@Route("/json/:arg", methods: const [POST])
Map jsonBody(String arg, @Body(JSON) Map json) => {"arg": arg, "json": json};

@Route("/text/:arg", methods: const [POST])
Map textBody(String arg, @Body(TEXT) String text) => {"arg": arg, "text": text};

@Route("/form/:arg", methods: const [POST])
Map formBody(String arg, @Body(FORM) Map form) => {"arg": arg, "form": form};

@Route("/attr/:arg")
String attr(@Attr() String name, String arg, {@Attr() int value: 0}) =>
    "$name $arg $value";

@Route("/jsonDynamicMap", methods: const [POST])
DynamicMap jsonBodyDynamicMap(@Body(JSON) DynamicMap json) =>
    new DynamicMap({"key": json.key.innerKey});

@Interceptor("/attr/.+")
Future<shelf.Response> interceptorAttr() {
  request.attributes["name"] = "name_attr";
  request.attributes["value"] = 1;
  return chain.next();
}
