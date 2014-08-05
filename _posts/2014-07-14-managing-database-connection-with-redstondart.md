---
layout: post
title: Managing Database Connections
author: Luiz Mineo
---

Accessing a database is problably the most common task of any web application. Nevertheless, a poor database connection management is also one of the most common source of problems you can find in a server, like slowness, freezes and crashs. In this post, I'll show some techiniques you can use to properly manage database connections using Redstone.dart.

Let's start with a simple example:


```dart
import 'package:redstone/server.dart' as app;
import 'package:mongo_dart/mongo_dart.dart';

final DB_URI = "mongodb://localhost/dbname";

///Returns all users recorded in the database
@app.Route('/services/users/list')
listUsers() {
  var conn = new Db(DB_URI);

  return conn.open().then((_) {

    return conn.collection("users").find().toList();

  }).whenComplete(() {
    conn.close();
  });

}

main() {
  
  app.setupConsoleLog();
  app.start();

}
```

The script above defines the `listUsers()` route, which connects to a MongoDB database, and returns all documents in the `users` collection. It shows how you can use the `Future.whenComplete()` method to guarantee that the connection will always be closed, even if the operation throws an error.

However, if you plan to add new routes to your server (like `addUser()`, for example), you'll note that this is not the ideal solution, since you need to copy and paste the code that handles the database connection for every route.

So, let's see how we can improve our script:

```dart
import 'package:redstone/server.dart' as app;
import 'package:mongo_dart/mongo_dart.dart';

final DB_URI = "mongodb://localhost/dbname";

@app.Interceptor('/.*')
dbManager() {
  var conn = new Db(DB_URI);

  conn.open().then((_) {

    //set the connection as a request attribute.
    //the attributes map allows the use of the dot notation. 
    app.request.attributes.conn = conn; //same as app.request.attributes["conn"] = conn;

    //call the next handler of the chain, close
    //the connection when it's done
    app.chain.next(() => conn.close());

  });

}

@app.Route('/services/users/list')
listUsers(@app.Attr() Db conn) =>
    conn.collection("users").find().toList();

```

Using an interceptor is the most common way to define a common behavior to a set of routes. If your are used to JEE applications, you can see an interceptor as a Filter, but with an asynchronous API. 

The `dbManager()` interceptor creates a new connection, save it in the `request.attributes` map, and uses the `chain` object to call the next handler of the current request (which can be a route or another interceptor). When the next handler finishes its execution, the interceptor closes the connection. 

To access a database connection in a route, you can annotate a paratemer with `@Attr`. Also, if you don't want to create an extra parameter for every route, you can define a getter that retrieves the connection of the current request:

```dart

Db get conn => app.request.attributes.conn;

@app.Route('/services/users/list')
listUsers() =>
    conn.collection("users").find().toList();

```

We can now easily add new routes to our server, but there is one more problem to solve: The server is creating a new connection for every request, which can lead to a serious performance problem. 

Some database drivers provides a built-in connection pool, which allows the application to reuse connections, so when a request is received, the server will require a connection that is already open, instead of creating a new one.

Unfortunately, the MongoDB driver for Dart doesn't provide a connection pool yet, but we can use the [connection_pool](http://pub.dartlang.org/packages/connection_pool) package to build one:  


```dart
import 'package:redstone/server.dart' as app;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:connection_pool/connection_pool.dart';
import 'package:di/di.dart';

final DB_URI = "mongodb://localhost/dbname";
final POOL_SIZE = 3;

//MongoDb connection pool
class MongoDbPool extends ConnectionPool<Db> {
  String uri;

  MongoDbPool(String this.uri, int poolSize) : super(poolSize);

  @override
  Future<Db> openNewConnection() {
    var conn = new Db(uri);
    return conn.open().then((_) => conn);
  }

  @override
  void closeConnection(Db conn) {
    conn.close();
  }
}

@app.Interceptor(r'/.*')
dbManager(MongoDbPool pool) {

  //get a connection from the pool
  pool.getConnection().then((managedConnection) {
    
    //set the connection as a request attribute
    app.request.attributes.conn = managedConnection.conn;

    //call the next handler of the chain. Release
    //the connection when it's done
    app.chain.next(() {
      if (app.chain.error is ConnectionException) {
        pool.releaseConnection(managedConnection, markAsInvalid: true);
      } else {
        pool.releaseConnection(managedConnection);
      }
    });
  });
}

Db get conn => app.request.attributes.conn;

@app.Route('/services/users/list')
listUsers() =>
    conn.collection("users").find().toList();

main() {
  
  app.addModule(
      new Module()
      ..bind(MongoDbPool, toValue: new MongoDbPool(DB_URI, POOL_SIZE)));

  app.setupConsoleLog();
  app.start();

}

```

The script above uses the dependency injection API (see the [di](http://pub.dartlang.org/packages/di) package) to register an instance of our pool, so the `dbManager()` interceptor can require it as a parameter.

Moreover, if you don't want to create a connection pool and a database interceptor for every application, you can take a look at the [redstone_mapper](http://pub.dartlang.org/packages/redstone_mapper) plugin. When used with a database extension (see [redstone_mapper_pg](http://pub.dartlang.org/packages/redstone_mapper_pg) and [redstone_mapper_mongo](http://pub.dartlang.org/packages/redstone_mapper_mongo)) the plugin does this job for you. Example:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_mongo/manager.dart';

final DB_URI = "mongodb://localhost/dbname";
final POOL_SIZE = 3;

main() {

  var dbManager = new MongoDbManager(DB_URI, poolSize: POOL_SIZE);

  app.addPlugin(getMapperPlugin(dbManager));
  app.setupConsoleLog();
  app.start();

}

MongoDb get dbConn => app.request.attributes.dbConn;

@app.Route('/services/users/list')
listUsers() =>
    dbConn.collection("users").find().toList();
```

Just one more tip: Our application can guarantee that the database connections are properly handled, even if an exception occurs. But when that happens, our users will receive an default html page, with the exception reason and its stack trace.

You can change that behaivor with an error handler:

```dart
import 'package:redstone/server.dart' as app;

@app.ErrorHandler(500)
onInternalError() => app.redirect("/internal_error.html");

```

You can also define an error handler for static content, and other for services:

```dart
import 'package:redstone/server.dart' as app;
import 'package:shelf/shelf.dart as shelf';

//redirect to the default error page
@app.ErrorHandler(500)
onInternalError() => app.redirect("/internal_error.html");

//for services, return a json
@app.ErrorHandler(500, urlPattern: '/services/.*')
onServiceInternalError() => new shelf.Response.internalServerError({"ERROR": "INTERNAL_ERROR"});
```

It's also possible to inspect the exception, so you can build a specific error message for each error:

```dart
import 'package:redstone/server.dart' as app;
import 'package:mongo_dart/mongo_dart.dart';

@app.ErrorHandler(500)
onInternalError() {
  
  if (app.chain.error is ConnectionException) {
    ...
  } else {
    ...
  }

}

```