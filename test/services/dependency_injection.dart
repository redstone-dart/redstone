library dependency_injection;

import 'dart:async';
import 'package:redstone/redstone.dart';
import 'package:shelf/shelf.dart' as shelf;

class A {
  String get value => "value_a";
}

class B {
  String get value => "value_b";
}

class C {
  A objA;
  B objB;

  C(this.objA, this.objB);

  String get value => "${objA.value} ${objB.value}";
}

@Route("/di")
String service(@Inject() A objA, @Inject() B objB, @Attr() C objC) =>
    "${objA.value} ${objB.value} ${objC.value}";

@Interceptor(r"/di")
Future interceptor(@Inject() C objC) async {
  request.attributes["objC"] = objC;
  await chain.next();
}

@Group("/group")
class ServiceGroup {
  C objC;

  ServiceGroup(this.objC);

  @Route("/di")
  String service() => objC.value;
}

@ErrorHandler(404)
shelf.Response errorHandler(@Inject() C objC) =>
    new shelf.Response.notFound(objC.value);
