---
layout: post
title: "How to deploy your Redstone.dart app to Heroku"
author: Luiz Mineo
---

Today I've got some time to play with the new [cedar-14](https://blog.heroku.com/archives/2014/8/19/cedar-14-public-beta) stack and the [Dart buildpack](https://github.com/igrigorik/heroku-buildpack-dart), and I'm impressed on how easy it is now to deploy Dart apps on [Heroku](http://heroku.com). 

Basically, to run on Heroku, your app must be configurable through environment variables. The minimal configuration that every heroku application must handle is the port number, where the server is allowed to bind to. Let's see an example:

```dart

import "dart:io";

import "package:redstone/server.dart" as app;

//Import services here

main(List<String> args) {

  app.setupConsoleLog();

  //check environment variables
  var port = _getConfig("PORT", "8080");

  //start the server
  app.start(port: int.parse(port));
}

_getConfig(String name, [defaultValue]) {
  var value = Platform.environment[name];
  if (value == null) {
    return defaultValue;
  }
  return value;
}

```

If your app also has client code, it's a good idea to make the path to the web folder configurable too.

```dart
import "dart:io";

import "package:redstone/server.dart" as app;
import "package:shelf_static/shelf_static.dart";

//Import services here

main(List<String> args) {

  app.setupConsoleLog();

  //check environment variables
  var port = _getConfig("PORT", "8080");
  var web = _getConfig("WEB_FOLDER", "web");

  //start the server
  app.setShelfHandler(createStaticHandler(web,
                      defaultDocument: "index.html"));
  app.start(port: int.parse(port));
}

_getConfig(String name, [defaultValue]) {
  var value = Platform.environment[name];
  if (value == null) {
    return defaultValue;
  }
  return value;
}


```

When you push your Dart application to Heroku, it uses the `pub build` command to compile the client code, and then starts the server. To allow Heroku to run your server, you need to create a `Procfile` file with the command to start it. For example, if your server entry-point is defined in the bin/server.dart file, the Procfile can have the following content:

```
web: ./dart-sdk/bin/dart bin/server.dart
```

With everything set up, you can use the [Heroku Toolbelt](https://toolbelt.heroku.com/) to deploy your app. To do so, just run the following commands
from the application root folder.

First, you need a git repository to transfer your app to Heroku. If you already have one, you can ignore this step:

```
$ git init
$ git add .
$ git commit -am "first commit"
```

Create a Heroku application using the cedar-14 stack:

```
$ heroku create -s cedar-14
```

Configure a Dart SDK archive. The following link points to Dart SDK 1.7-dev.4.6, but you can get another version 
[here](https://www.dartlang.org/tools/download_archive/) (be sure to get a Linux 64-bit build):

```
$ heroku config:set DART_SDK_URL=https://storage.googleapis.com/dart-archive/channels/dev/release/41090/sdk/dartsdk-linux-x64-release.zip
```

Configure the Dart buildpack:

```
$ heroku config:add BUILDPACK_URL=https://github.com/igrigorik/heroku-buildpack-dart.git
```

Configure the path to the client code:

```
$ heroku config:set WEB_FOLDER=build/web
```

And finally, push the application to Heroku:

```
$ git push heroku master
```

If everything goes right, your app will be ready for use! You can see its URL in the output of the `git push` command. It's also possible to access it through the Heroku Dashboard. 

For more information, take a look at the [Heroku](https://devcenter.heroku.com/articles/how-heroku-works) and [Dart buildpack](https://github.com/igrigorik/heroku-buildpack-dart) documentations. You can also see a more complete example [here](https://github.com/luizmineo/io_2014_contacts_demo).
