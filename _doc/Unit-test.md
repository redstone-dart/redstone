---
layout: doc
menu_item: doc
title: Unit Test
prev: Shelf-Middlewares
next: Server-Configuration
---
Basically, to create a test, you just need to:

* Call `setUp()` to load your handlers
* Create a `MockRequest`
* Call `dispatch()` to send your request
* Inspect the returned response
* Call `tearDown()` to unload your handlers 

Example:

```dart
library services;

import 'package:redstone/server.dart' as app;

@app.Route("/user/:username")
helloUser(String username) => "hello, $username";
```

```dart
import 'package:unittest/unittest.dart';

import 'package:redstone/server.dart' as app;
import 'package:redstone/mocks.dart';

import 'package:your_package_name/services.dart';

main() {

  //load handlers in 'services' library
  setUp(() => app.setUp([#services]));
  
  //remove all loaded handlers
  tearDown(() => app.tearDown());
  
  test("hello service", () {
    //create a mock request
    var req = new MockRequest("/user/luiz");
    //dispatch the request
    return app.dispatch(req).then((resp) {
      //verify the response
      expect(resp.statusCode, equals(200));
      expect(resp.mockContent, equals("hello, luiz"));
    });
  })
  
}
```

## MockRequest Examples

* GET request: /service

```dart
var req = new MockRequest("/service");
```

* GET request: /service?param=value

```dart
var req = new MockRequest("/service", queryParams: {"param": "value"});
```

* POST request: /service, JSON data

```dart
var req = new MockRequest("/service", method: app.POST, bodyType: app.JSON, body: {
  "key1": "value1",
  "key2": "value2"
});
```

* POST request: /service, FORM data

```dart
var req = new MockRequest("/service", method: app.POST, bodyType: app.FORM, body: {
  "key1": "value1",
  "key2": "value2"
});
```

* POST request: /service, FORM data, multipart request

```dart
import "dart:convert";
import "dart:io";

...

var file = new app.HttpBodyFileUpload(ContentType.parse("text/plain"), 
                                      "test.txt", 
                                      UTF8.encode("test"));

var req = new MockRequest("/service", method: app.POST, bodyType: app.FORM, body: {
  "key1": "value1",
  "file": file
});
```

* Mocking a session

```dart
var req = new MockRequest("/service", 
  session: new MockHttpSession("session_id", {"user": "username"}));
```
