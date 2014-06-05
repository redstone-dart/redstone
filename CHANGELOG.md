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
