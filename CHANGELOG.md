## v.0.6.8

* Exposed endpoint mirrors to let a user create his plugin.

## v0.6.7

* Fixed issue with query parameters not being managed correctly when the type is `List`.
* Redirections are not considered as error anymore. When `showError: true`, it won't be an error anymore.
* Fixed analyzer warnings.
* Cleaned the Group Scanner.
* Refactored some tests
* Added more tests

A big thanks to @sestegra for all those very welcomed changes.

## v0.6.6
Drop package:crypto. Update other package dependencies and fix some strong-mode issues.
Also fixes definitions of == and hashCode.

## v0.6.5
Bug fix: http_body_parser tries to parse body of GET Requests

## v0.6.4

* Fixed a bug with HTTPS, where one could not start the server when using HTTPS.
* Updated dependencies

## v0.6.3

* Updated dependencies in order to update plugins.

## v0.6.2

* Updated dependencies in order to update plugins.

## v0.6.1

### BREAKING CHANGE
In this version, the minimum SDK version was bumped to 1.13.0 because of the [Boring SSL update.](http://news.dartlang.org/2015/09/dart-adopts-boringssl.html)

* Updated dependencies
* Upgraded tests with SSL to the new Boring SSL stuff.
* Converted the documentation to 0.6.x

## v0.6.0-beta.2

**NOTE: this is a pre-release version!**

* Updated test package dependency
* Updated the https example with the new BoringSSL stuff. That means the `secureOptions` in the server.start() function
takes a `#context` which is a `SecurityContext`. See `example/https.dart` for more usage example.

## v0.6.0-beta.1

**NOTE: this is a pre-release version!**

* Updated to shelf 0.6
* Added the optional parameter `headers` to `chain.forward()`
* Added the `request.handlerPath` property (see [shelf.Request.handlerPath](http://www.dartdocs.org/documentation/shelf/0.6.0/index.html#shelf/shelf.Request@id_handlerPath))
* Bug fixes. 

## v0.6.0-alpha.3

**NOTE: this is a pre-release version!**

* Added new constants for the commons http methods. [#80](https://github.com/luizmineo/redstone.dart/issues/80)
* Added the `shared` and `logSetUp` optional parameters to the `start()` function

## v0.6.0-alpha.2

**NOTE: this is a pre-release version!**

* Renamed `request.queryParams` to `request.queryParameters`
* Renamed `request.pathParams` to `request.urlParameters`
* Fix support for websocket connections
* Fix code comments to match the new API

## v0.6.0-alpha.1

**NOTE: this is a pre-release version!**

* **Version highlights:**

    * Fully rewritten from scratch! (The code base now has a better library layout, which is easier to maintain and evolve)
    * Polished API (see breaking changes)
    * Added the `chain.forward()` function, which allows routes, interceptors and error handlers to internally dispatch a request to another resource
    * Added the `chain.createResponse()` function, which can be used to easily create `shelf.Response` objects
    * Better support for `async/await` (see breaking changes)

* **BREAKING CHANGES:**

    * Renamed `redstone/server.dart` to `redstone/redstone.dart`
    * Renamed `QueryMap` to `DynamicMap`
    * Removed `Route.matchSubPaths` property (`route_hierarchical` supports this by default now)
    * Renamed `setUp()` and `tearDown()` to `redstoneSetUp()` and `redstoneTearDown()`. This avoids conflicts with the unittest package, if redstone is imported without a lib prefix.
    * `redstoneSetUp()` now returns a `Future`. You need to wait for its completion before dispatching any request.
    * Removed `authenticateBasic()` top level function
    * Moved `parseAuthorizationHeader()` top level function to the `request` object (`request.parseAuthorizationHeader()`)
    * Removed the `chain.interrupt()` function. 
    * The `chain.next()` and `chain.abort()` functions now return a `Future<shelf.Response>`. It's necessary to wait for the completion of the returned future when calling one of these functions, although, it's now possible to use them with async/await expressions. See the example below.
    * The `chain.redirect()` function now returns a `shelf.Response`
    * Redstone now generates an error page for every response which status code is less than 200, or greater than 299. To prevent this behavior, set `showErrorPage` to false
    * For interceptors and error handlers, it's now necessary to annotate injectable parameters with `@Inject`. Although, they now also accept the `@Attr` annotation, which binds a parameter with a request attribute.
    * Plugin API: Some methods of the `Manager` object are now getters.
    * Plugin API: Renamed `RouteHandler` to `DynamicRoute`
    * Plugin API: Renamed `Handler` to `DynamicHandler`
    * Plugin API: `DynamicRoute` and `RouteWrapper` do not receive the `pathSegments` map anymore, although, it can be accessed through the `request.pathSegments` property
    * `request.queryParams` is now a `DynamicMap<String, List<String>>`. Also, you can now use the `@QueryParam` annotation with `List` objects

**Example: CORS Interceptor**

```dart
import 'package:redstone/redstone.dart';
import "package:shelf/shelf.dart" as shelf;

@Interceptor(r'/.*')
handleCORS() async {
  if (request.method != "OPTIONS") {
    await chain.next();
  }
  return response.change(headers: {"Access-Control-Allow-Origin": "*"});
}
```

* **TODO:**
    * Improve unit tests
    * Update plugins (redstone_mapper and redstone_web_socket aren't compatible with this version yet)
    * Improve documentation and website

## v0.5.19
* Fix: Error when setting `Intereptor.parseRequestBody = true` (Thanks to [platelk](https://github.com/platelk). See PR [#46](https://github.com/luizmineo/redstone.dart/pull/46)).

## v0.5.18
* Updated to Grinder v0.6.1 (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Deploy))

## v0.5.17
* Updated dependencies.
* Added the `autoCompress` parameter to the `start()` function.
* Added `Route.statusCode` and `DefaultRoute.statusCode` parameters.

**Note:** this version requires Dart 1.7 or above

## v0.5.16
* Fix: Setting a new value in a `QueryMap` with the dot notation is not working properly.

## v0.5.15
* Fix: Correctly log an exception when no stack trace is provided

## v0.5.14
* Fix: `Manager.findMethods()` should include inherited methods.

## v0.5.13
* Improved plugin API: 
    * Added the `Manager.getInjector()` and `Manager.createInjector()` methods, which allow plugins to retrieve objects from di modules more easily.
    * Added the `Manager.findFunctions()`, `Manager.findClasses()` and `Manager.findMethods()` methods, which allow plugins to scan imported libraries.
    * Added the `Manager.getShelfHandler()` and `Manager.setShelfHandler()` methods, which allow plugins to access and replace the current installed shelf handler.

## v0.5.12
* New feature: If a route has `matchSubPaths = true`, the requested subpath can be assigned to a parameter (see issue #36).

## v0.5.11
* Minor performance fix: Redstone.dart shouldn't create a new `shelf.Pipeline` per request.

## v0.5.10
* Upgraded to di 2.0.1

## v0.5.9
* Fix: Redstone.dart can't be used with shelf_web_socket (issue #30).

## v0.5.8+1
* Fixed docgen issue (see [dartdocs log](http://www.dartdocs.org/buildlogs/b-4066095f44173ae2e2ca3bb6a2f72-startupscript.log))

## v0.5.8
* Added support for https (Thanks to [vicb](https://github.com/vicb) PR #26, see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Server-Configuration#secure-connections-https))
* Code cleanup (Thanks to [vicb](https://github.com/vicb) PR #29)
* Fix: Properly handle error responses produced by a shelf handler

## v0.5.7+2
* Improved error handling. See issue #24.

## v0.5.7+1
* Fixed docgen issue (see [dartdocs log](http://www.dartdocs.org/buildlogs/b-324b8609c46a0a8b9060d0b59539a-startupscript.log))

## v0.5.7
* Improved plugin API:
    * It's now possible to inspect installed routes, interceptors, error handlers and groups.
    * Added the `Manager.addRouteWrapper()` method, which allows plugins to modify routes that are annotated with a specific annotation.

## v0.5.6
* Fixed logging issues.

## v0.5.5+1
* Fixed issue with docgen.

## v0.5.5
* Added the `ErrorResponse` class. A route can return or throw an ErrorResponse, to respond a request with a status code different than 200. 

## v0.5.4
* Fix: Response processors are not being invoked when a route returns a `Future` (Plugin API).
* Code cleanup (Thanks to [vicb](https://github.com/vicb) PR #20)
* Added the `QueryMap` class, a Map wrapper that allows the use of the dot notation to retreive its values (Thanks to [digitalfiz](https://github.com/digitalfiz) issue #18)
    * `app.request.queryParams`, `app.request.headers` and `app.request.attributes` now returns a QueryMap.
    * The request body can also be retrieved as a QueryMap.
* Added the `handleRequest(HttpRequest)` method.

## v0.5.3+1
- Widen the version constraint for `di`

## v0.5.3
- Improved integration with Shelf
- `shelf.Request.hijack()` method is now supported (although it does not work in unit tests)
- The default error handler now uses the `stack_trace` package to print stack traces.

## v0.5.2
- Fix: Request's state is being improperly cached (see issue #16).

## v0.5.1
- Fix: Correctly handle route exceptions.

## v0.5.0
- Added support for Shelf middlewares and handlers (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Shelf-Middlewares))
- BREAKING CHANGE: Redstone.dart will no longer serve static files directly. You can use a Shelf handler for this (see [documention](https://github.com/luizmineo/redstone.dart/wiki/Server-Configuration))
- BREAKING CHANGE: It's no longer possible to access `HttpRequest` and `HttpResponse`. If you need to inspect or modify the response, you can use the global `response` object (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Routes#the-response-object))
- It's now possible to define multiple routes to the same path (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Routes#http-methods))
- Added `@DefaultRoute` annotation (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Groups))
- Added `serveRequests(Stream<HttpRequest> requests)` method, which is an alternative to the `start()` method.

## v0.4.0
- Added new annotations: `@Install` and `@Ignore` (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Importing-libraries))
- Added support for plugins (see [documentation](https://github.com/luizmineo/redstone.dart/wiki/Plugins))

## v0.3.1
- Renamed project to **Redstone.dart**
- New and improved documentation

## v0.3.0
- Added `Route.matchSubPaths` property (see issue #5)
- Added `ErrorHandler.urlPattern` property (check documentation for details)
- Added request attributes (check documentation for details)
- Added support for dependency injection (check documentation for details)

## v0.2.1
- Added support for basic authentication (thanks **Y12STUDIO** for the contribution)
  - Added `parseAuthorizationHeader()` method.
  - Added `authenticateBasic()` method.

## v0.2.0
- BREAKING CHANGES (check documentation for more details):
  - [VirtualDirectory](https://api.dartlang.org/apidocs/channels/stable/dartdoc-viewer/http_server/http_server.VirtualDirectory) is now configured with `jailRoot = true` and `followLinks = false`. You can change these flags through `start()` method.
  - For security and perfomance reasons, the parse of request body is now delayed as much as possible, so interceptors will receive `null` if they call `request.body` (although request.bodyType is still filled). If your interceptor need to inspect the request body, you can set `Interceptor.parseRequestBody = true`.
  - Multipart requests (file uploads) are now refused by default. If your method need to receive multipart requests, you can set `Route.allowMultipartRequest = true`.
  - All arguments of `chain.interrupt()` method are now optional.
- Bug fixes in `abort()`, `redirect()` and `chain.interrupt()` methods. (see issue #3).

## v0.1.2
- Fix: bloodless crashes on Dart 1.3.

## v0.1.1
- Fix: malformed requests can cause a crash

## v0.1.0
- Bug fixes
- BREAKING CHANGE: `chain.next()` now receives a callback, instead of returning a `Future`
- Added new API for unit tests
- Updated documentation

## v0.0.4
- Fix: `chain.interrupt()` is not closing the `HttpResponse` stream

## v0.0.3
- Added a [grinder](http://pub.dartlang.org/packages/grinder) task to properly copy sever's files to the build folder
- Updated documentation with a better approach for building projects

## v0.0.2
- Small fix to VirtualDirectory configuration

## v0.0.1
- First release
