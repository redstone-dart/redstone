---
layout: doc
menu_item: doc
title: Unit Test
docprev: Shelf-Middlewares
docnext: Server-Configuration

---
Basically, to create a test, you just need to:

* Call `redstoneSetUp()` to load your handlers
* Create a `MockRequest`
* Call `dispatch()` to send your request
* Inspect the returned response
* Call `redstoneTearDown()` to unload your handlers 

Example:

{% include code.func code="services.dart" %}

{% include code.func code="services_test.dart" %}

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

// ...

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
