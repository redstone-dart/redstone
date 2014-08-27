---
layout: doc
menu_item: doc
title: redstone_web_socket
prev: redstone_mapper_pg
---
[redstone_web_socket](http://pub.dartlang.org/packages/redstone_web_socket) is a web socket plugin for [Redstone.dart](http://redstonedart.org). It uses the 
[shelf_web_socket](http://pub.dartlang.org/packages/shelf_web_socket) package to create web socket handlers.

### Using @WebSocketHandler with functions

If a function is annotated with `@WebSocketHandler`, it'll be invoked with a [CompatibleWebSocket](https://api.dartlang.org/apidocs/channels/be/dartdoc-viewer/http_parser/http_parser.CompatibleWebSocket) object for
every new established connection:

```dart
@WebSocketHandler("/ws")
onConnection(websocket) {
  websocket.listen((message) {
    websocket.add("echo $message");
  });
}
```

### Using @WebSocketHandler with classes

If a class is annotated with `@WebSocketHandler`, the plugin will install a event listener for every method annotated 
with `@OnOpen`, `@OnMessage`, `@OnError` and `@OnClose`:

```dart

@WebSocketHandler("/ws")
class ServerEndPoint {

  @OnOpen()
  void onOpen(WebSocketSession session) {
    print("connection established");
  }

  @OnMessage()
  void onMessage(String message, WebSocketSession session) {
    print("message received: $message");
    session.connection.add("echo $message");
  }

  @OnError()
  void onError(error, WebSocketSession session) {
    print("error: $error");
  }

  @OnClose()
  void onClose(WebSocketSession session) {
    print("connection closed");
  }

}

```

Like redstone [groups](http://redstonedart.org/doc/Groups.html), the class will be instantiated only once, and it
can request injectable objects with a constructor (see [dependency injection](http://redstonedart.org/doc/Dependency-Injection.html)).

### Installing handlers

To install web socket handlers, you just have to import `redstone_web_socket.dart` and call `getWebSocketPlugin()`:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_web_socket/redstone_web_socket.dart';

void main() {
  app.setupConsoleLog();
  
  //install web socket handlers
  app.addPlugin(getWebSocketPlugin());
  
  app.start();
}
```

### Unit tests

This package also provides a simple mock client, which can be used in unit tests:

```dart
import 'package:redstone/server.dart' as app;
import 'package:redstone_web_socket/redstone_web_socket.dart';
import 'package:unittest/unittest.dart';

main() {
  
  test("Test echo service", () {
  
    var completer = new Completer();
    var socket = new MockWebSocket();
    
    socket.listen((message) {
      
      expect(message, equals("echo message"));
      
      completer.complete();
    });
    
    openMockConnection("/ws", socket);
    
    socket.add("message");
    
    return completer.future;
  
  });

}
```