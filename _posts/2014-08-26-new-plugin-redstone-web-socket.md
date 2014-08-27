---
layout: post
title: "New Redstone.dart plugin: redstone_web_socket"
author: Luiz Mineo
---

A new Redstone.dart plugin is available on pub: [redstone_web_socket](http://pub.dartlang.org/packages/redstone_web_socket).

This plugin is a wrapper to the [shelf_web_socket](http://pub.dartlang.org/packages/shelf_web_socket) package. It provides a `@WebSocketHandler` annotation, which can be used to define web socket handlers:

```dart
@WebSocketHandler("/ws")
onConnection(websocket) {
  websocket.listen((message) {
    websocket.add("echo $message");
  });
}
```

The `@WebSocketHandler` annotation can also be used with classes:

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

The plugin also provides a simple mock client, which can be used to test web socket handlers:

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

For more details, please take a look at the [documentation](http://redstonedart.org/doc/redstone_web_socket.html). 