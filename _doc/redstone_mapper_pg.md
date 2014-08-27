---
layout: doc
menu_item: doc
title: redstone_mapper_pg
prev: redstone_mapper_mongo
next: redstone_web_socket
---
[redstone_mapper_pg](http://pub.dartlang.org/packages/redstone_mapper_pg) is a PostgreSQL extension for [redstone_mapper](http://pub.dartlang.org/packages/redstone_mapper).

This package is a wrapper for the [postgresql](https://github.com/xxgreg/postgresql) driver.

### Usage:

Create a `PostgreSqlManager` to manage connections with the database:

```dart
var uri = "postgres://testdb:password@localhost:5432/testdb";
var dbManager = new PostgreSqlManager(uri, min: 1, max: 3);
```

If you are using redstone_mapper as a Redstone.dart plugin, you can pass a `PostgreSqlManager` to `getMapperPlugin()`, 
so a database connection will be available for every request:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_pg/manager.dart';

main() {
  
  var uri = "postgres://testdb:password@localhost:5432/testdb";
  var dbManager = new PostgreSqlManager(uri, min: 1, max: 3);
  
  app.addPlugin(getMapperPlugin(dbManager));
  app.setupConsoleLog();
  app.start();
  
}

//redstone_mapper will create a "dbConn" attribute
//for every request.
@app.Route("/services/users/list")
listUsers(@app.Attr() PostgreSql dbConn) =>
   dbConn.innerConn.query("select * from users").toList();
   
//If you prefer, you can also create a getter to access the
//database connection of the current request, so
//you don't need to add an extra parameter for every route.
PostgreSql get postgreSql => app.request.attributes.dbConn;

```

The `PostgreSql` object is a wrapper that provides helper functions for encoding and decoding objects:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_mapper/mapper.dart';
import 'package:redstone_mapper/plugin.dart';
import 'package:redstone_mapper_pg/manager.dart';

class User {
  
  @Field()
  int id;

  @Field()
  String username;

  @Field()
  String password;
  
}

PostgreSql get postgreSql => app.request.attributes.dbConn;

@app.Route("/services/users/list")
@Encode()
Future<List<User>> listUsers() => 
  //query users from the "user" table, and decode
  //the result to List<User>.
  postgreSql.query("select * from user", User);

@app.Route("/services/users/add", methods: const[app.POST])
Future addUser(@Decode() User user) => 
  //encode user, and insert it in the "user" table.
  postgreSql.execute("insert into users (name, password) "
                     "values (@username, @password)", user);

```

However, the `PostgreSql` class doesn't hide the `postgresql` API. You can access 
the original connection object with the `PostgreSql.innerConn` property.

Moreover, you can use a `PostgreSqlService` to handle operations that concerns the same entity type:

```dart

PostgreSqlService<User> userService = new PostgreSqlService<User>();

@app.Route("/services/users/list")
@Encode()
Future<List<User>> listUsers() => userService.query("select * from user"); 

@app.Route("/services/users/add", methods: const[app.POST])
Future addUser(@Decode() User user) => 
  postgreSql.execute("insert into users (name, password) "
                     "values (@username, @password)", user);

```

It's also possible to inherit from `PostgreSqlService`:

```dart
@app.Group("/services/users")
Class UserService extends PostgreSqlService<User> {

  @app.Route("/list")
  @Encode()
  Future<List<User>> list() => query("select * from user");

  @app.Route("/add")
  Future add(@Decode() User user) =>
    execute("insert into users (name, password) "
            "values (@username, @password)", user);

}
```

`PostgreSqlService` will by default use the database connection associated with the current request. If you are not using
Redstone.dart, be sure to use the `PostgreSqlService.fromConnection()` constructor to create a new service.