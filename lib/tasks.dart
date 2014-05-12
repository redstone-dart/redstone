library redstone_tasks;

import 'dart:io';
import 'package:grinder/grinder.dart';
import 'package:grinder/grinder_files.dart';


/// A task to properly deploy server's files
deployServer(GrinderContext ctx) {

  Directory devDir = joinDir(Directory.current, ["bin"]);
  Directory buildDir = joinDir(Directory.current, ["build", "bin"]);

  deleteEntity(buildDir, ctx);
  copyDirectory(devDir, buildDir);

  String buildFile = Platform.script.pathSegments.last;
  deleteEntity(joinFile(buildDir, [buildFile]), ctx);
}
