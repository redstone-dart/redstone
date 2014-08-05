---
layout: doc
menu_item: doc
title: redstone_mapper_mongo
prev: redstone_mapper
next: redstone_mapper_pg
---
[redstone_mapper_mongo](http://pub.dartlang.org/packages/redstone_mapper_mongo) is a MongoDB extension for [redstone_mapper](http://pub.dartlang.org/packages/redstone_mapper).

This package is a wrapper for the [mongo_dart](https://github.com/vadimtsushko/mongo_dart) driver.

### Usage:

Create a `MongoDbManager` to manage connections with the database:

```dart
var dbManager = new MongoDbManager("mongodb://localhost/dbname", poolSize: 3);
```

If you are using redstone_mapper as a Redstone.dart plugin, you can pass a `MongoDbManager` to `getMapperPlugin()`, 
so a database connection will be available for every request:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_mongo/manager.dart';

main() {
  
  var dbManager = new MongoDbManager("mongodb://localhost/dbname", poolSize: 3);
  
  app.addPlugin(getMapperPlugin(dbManager));
  app.setupConsoleLog();
  app.start();
  
}

//redstone_mapper will create a "dbConn" attribute
//for every request.
@app.Route("/services/users/list")
listUsers(@app.Attr() MongoDb dbConn) =>
   dbConn.collection("users").find().toList();
   
//If you prefer, you can also create a getter to access the
//database connection of the current request, so
//you don't need to add an extra parameter for every route.
MongoDb get mongoDb => app.request.attributes.dbConn;

```

The `MongoDb` object is a wrapper that provides helper functions for encoding and decoding objects:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_mongo/manager.dart';
import 'package:redstone_mapper_mongo/metadata.dart';

class User {
  
  //@Id is a special annotation to handle the "_id" document field, 
  //it instructs redstone_mapper to convert ObjectId values to String, 
  //and vice versa.
  @Id()
  String id;

  @Field()
  String username;

  @Field()
  String password;
  
}

MongoDb get mongoDb => app.request.attributes.dbConn;

@app.Route("/services/users/list")
@Encode()
Future<List<User>> listUsers() => 
  //query documents from the "users" collection, and decode
  //the result to List<User>.
  mongoDb.find("users", User); 

@app.Route("/services/users/add", methods: const[app.POST])
Future addUser(@Decode() User user) => 
  //encode user, and insert it in the "users" collection.
  mongoDb.insert("users", user);

```

However, the `MongoDb` class doesn't hide the `mongo_dart` API. You can access a `DbCollection` with the `MongoDb.collection()` method. 
Also, you can access the original connection object with the `MongoDb.innerConn` property.

Moreover, you can use a `MongoDbService` to handle operations that concerns the same document type:

```dart

MongoDbService<User> userService = new MongoDbService<User>("users");

@app.Route("/services/users/list")
@Encode()
Future<List<User>> listUsers() => userService.find(); 

@app.Route("/services/users/add", methods: const[app.POST])
Future addUser(@Decode() User user) => userService.insert(user);

```

It's also possible to inherit from `MongoDbService`:

```dart
@app.Group("/services/users")
Class UserService extends MongoDbService<User> {

  UserService() : super("users");

  @app.Route("/list")
  @Encode()
  Future<List<User>> list() => find();

  @app.Route("/add")
  Future add(@Decode() User user) => insert(user);

}
```

`MongoDbService` will by default use the database connection associated with the current request. If you are not using
Redstone.dart, be sure to use the `MongoDbService.fromConnection()` constructor to create a new service.