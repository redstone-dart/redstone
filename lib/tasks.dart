library redstone.tasks;

import 'dart:io';
import 'package:grinder/grinder.dart';

/// A task to properly deploy server files
void deployServer(GrinderContext ctx) {
  Directory devDir = joinDir(Directory.current, ["bin"]);
  Directory buildDir = joinDir(Directory.current, ["build", "bin"]);

  delete(buildDir);
  copy(devDir, buildDir);

  String buildFile = Platform.script.pathSegments.last;
  delete(joinFile(buildDir, [buildFile]));
}
