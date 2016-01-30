library inspect;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

//test metadata access

@Route("/route1")
String route1() => "route1";

@Route("/route2")
String route2() => "route2";

@Interceptor("/interceptor")
Future<shelf.Response> interceptor() => chain.next();

@ErrorHandler(333)
dynamic errorHandler() => null;

@Group("/group")
class GroupPluginTest {
  @Route("/route1")
  String route1() => "route1";

  @Route("/route2")
  String route2() => "route2";

  @Interceptor("/interceptor")
  Future<shelf.Response> interceptor() => chain.next();

  @ErrorHandler(333)
  dynamic errorHandler() => null;
}
