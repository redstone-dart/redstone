library inspect;

import 'package:redstone/redstone.dart';

//test metadata access

@Route("/route1")
route1() => "route1";

@Route("/route2")
route2() => "route2";

@Interceptor("/interceptor")
interceptor() => chain.next();

@ErrorHandler(333)
errorHandler() => null;

@Group("/group")
class GroupPluginTest {
  @Route("/route1")
  route1() => "route1";

  @Route("/route2")
  route2() => "route2";

  @Interceptor("/interceptor")
  interceptor() => chain.next();

  @ErrorHandler(333)
  errorHandler() => null;
}
