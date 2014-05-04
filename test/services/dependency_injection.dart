library dependency_injection;

import 'package:bloodless/server.dart' as app;

class A {
  
  String get value => "value_a";
  
}

class B {
  
  String get value => "value_b";
  
}

class C {
  
  A objA;
  B objB;
  
  C(A this.objA, B this.objB);
  
  String get value => "${objA.value} ${objB.value}";
}

@app.Route("/di")
service(@app.Inject() A objA, 
        @app.Inject() B objB, 
        @app.Attr() C objC) => 
    "${objA.value} ${objB.value} ${objC.value}";
    
@app.Interceptor(r"/di")
interceptor(C objC) {
  app.request.attributes["objC"] = objC;
  app.chain.next();
}

@app.Group("/group")
class Group {
  
  C objC;
  
  Group(C this.objC);
  
  @app.Route("/di")
  service() => objC.value;
  
}

@app.ErrorHandler(404)
errorHandler(C objC) => app.request.response.write(objC.value); 
