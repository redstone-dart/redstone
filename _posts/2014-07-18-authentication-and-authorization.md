---
layout: post
title: Authentication and Authorization
author: Luiz Mineo
---

One of the questions I get most often is how to implement security constraints with Redstone.dart. Some time ago, I've published a [simple example](https://github.com/luizmineo/auth_example) that illustrates how the Redstone.dart API can be used to implement authentication and authorization. In this post, I'll explain this example in details.

First of all, let's download and execute it. The project is available on [github](https://github.com/luizmineo/auth_example), so you can just clone its repository:

```
$ git clone https://github.com/luizmineo/auth_example.git
```

(Also, you can download it as a [zip file](https://github.com/luizmineo/auth_example/archive/master.zip))

Before running it, be sure to have a [MongoDB](http://www.mongodb.org/) instance available in your environment. By default, the application will try to connect to a local MongoDB instance, and create/use a database named "auth_example". Take a look at the `bin/server.dart` file to change these settings.

If you are using Ubuntu, or other Debian based linux distribution, you can just do the following to install MongoDB:

```
$ sudo apt-get install mongodb
```

Now, open up [Dart Editor](https://www.dartlang.org/tools/editor/), go to `File -> Open Existing Folder...` and select the project folder.

To run the application, we need to create two launch configurations: One to start our server, and another to start the client in Dartium. 

Go to `Run -> Manage Launches`.

To create the server launch:

* Create a new command-line launch
* Set *Dart Script* to *bin/server.dart*
* Set *Working Directory* to the project path
* Click on the *Apply* button

To create the client lauch:

* Create a new Dartium launch
* Change *Launch Target* to *URL*
* Set *URL* to *http://localhost:8080*
* Set *Source Location* to the project path
* Uncheck the *Use pub serve to serve the application* option
* Click on the *Apply* button

Now, start the server and then the client. If everything went right, you'll see a very basic html page. It has no style, just a bunch of html controls that we can use to test our server.

![auth_example html page](/assets/img/auth_example_print.png)

First, let's try to access a private service. Go to the "Echo service" form, write something in the text input field, and click on the "Send" button. Instead of returning the input, the service will return a 401 status code.

Now create a new user and authenticate with it. If you try the echo service again, it will return the input. If your user is an admin, you can also execute the users service.

Pretty cool, right? So, how does it work?

Open up the `lib/authentication.dart` file. You'll find our `authenticationFilter()` interceptor.


```dart

@app.Interceptor(r'/services/private/.+')
authenticationFilter() {
  if (app.request.session["username"] == null) {
    app.chain.interrupt(statusCode: HttpStatus.UNAUTHORIZED, responseValue: {"error": "NOT_AUTHENTICATED"});
  } else {
    app.chain.next();
  }
}

```

This interceptor is applied to any request which path starts with `/services/private`. It checks if the corresponding session has an "username" attribute. If so, the interceptor calls the next handler of the chain, otherwise, it returns a response with the 401 status code.

In the same script, you'll find the login and logout services:

```dart

@app.Route("/services/login", methods: const[app.POST])
login(@app.Attr() Db conn, @app.Body(app.JSON) Map body) {
  var userCollection = conn.collection("user");
  if (body["username"] == null || body["password"] == null) {
    return {"success": false, "error": "WRONG_USER_OR_PASSWORD"};
  }
  var pass = encryptPassword(body["password"].trim());
  return userCollection.findOne({"username": body["username"], "password": pass})
      .then((user) {
        if (user == null) {
          return {
            "success": false,
            "error": "WRONG_USER_OR_PASSWORD"
          };
        }
        
        var session = app.request.session;
        session["username"] = user["username"];
        
        Set roles = new Set();
        bool admin = user["admin"];
        if (admin != null && admin) {
          roles.add(ADMIN);
        }
        session["roles"] = roles;
        
        return {"success": true};
      });
}

@app.Route("/services/logout")
logout() {
  app.request.session.destroy();
  return {"success": true};
}

```

The login service verifies if the provided user exists in the database. If it does, it creates the "username" and "roles" attributes in the corresponding http session. The logout service just destroy the current session.

To create a private service, which can be executed only by authenticated users, we can just put it under the `/services/private` path. If you open the `lib/services.dart` file, you'll see the echo service implementation:

```dart

//A private service. Any authenticated user can execute 'echo'
@app.Route("/services/private/echo/:arg")
echo(String arg) => arg;

```

Now we need a way to define services that can be executed only by admin users. We can just define another interceptor to the `/services/private/admin/.+` path pattern, but that wouldn't be an ideal solution. Some applications can have a lot of roles (or user types), and associate each role with a path can be impractical. Instead, we will create an authorization plugin.

Open up the `lib/authorization.dart` file:

```dart

const String ADMIN = "ADMIN";

class Secure {
  
  final String role;
  
  const Secure(this.role);
  
}

void AuthorizationPlugin(app.Manager manager) {
  
  manager.addRouteWrapper(Secure, (metadata, pathSegments, injector, request, route) {
    
    String role = (metadata as Secure).role;
    Set userRoles = app.request.session["roles"];
    if (!userRoles.contains(role)) {
      throw new app.ErrorResponse(403, {"error": "NOT_AUTHORIZED"});
    }
    
    return route(pathSegments, injector, request);
    
  }, includeGroups: true);
  
}

```

A Redstone.dart plugin is just a function that receives a `Manager` object. The manager allows a plugin to inspect the current server structure (installed routes, interceptors, error handlers and groups) and modify it. Our authorization plugin defines a `Secure` annotation, and then add a wrapper to any route that is annotated with it. You can see a wrapper as a [Shelf middleware](https://github.com/dart-lang/bleeding_edge/tree/master/dart/pkg/shelf#handlers-and-middleware), it's a function that receives the target route as an argument, and may or may not forward the request to it.

If you open the `bin/server.dart` file, you'll see that the `addPlugin()` function is used to install our authorization plugin:

```dart
app.addPlugin(AuthorizationPlugin);
```

Now, to create a service that can be executed only by authenticated users that are admin, we can just put it under the `/services/private` path, and annotate it with `@Secure`:

```dart
//A private service. Only authenticated users with the 'ADMIN' role
//can view the list of registered users
@app.Route("/services/private/listusers")
@Secure(ADMIN)
listUsers(@app.Attr() Db conn) {
  
  var userCollection = conn.collection("user");
  return userCollection.find(where.excludeFields(const ["_id", "password"])).toList();
  
}
```

