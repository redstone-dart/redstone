import 'package:redstone/redstone.dart' as app;
import 'package:di/di.dart';

main() {
  app.addModule(new Module()
      ..bind(ClassA)
      ..bind(ClassB));

  app.setupConsoleLog();
  app.start();
}