library redstone.src.metadata;

import 'dart:convert' as conv;

import 'constants.dart';

abstract class RequestTarget {
  List<String> get methods;

  String get responseType;

  int get statusCode;

  bool get allowMultipartRequest;

  conv.Encoding get encoding;
}

/// An annotation to define targets.
///
/// [urlTemplate] is the url of the target, and can contains arguments prefixed with ':'.
/// [methods] are the HTTP methods accepted by this target, and defaults to GET.
/// The [encoding] is the default encoding that will be used to parse the request.
/// The [responseType] is the content type of the response. If it's not provided,
/// the framework will generate it based on the value returned by the method.
/// The [statusCode] is the default status of the response, and defaults to 200.
/// If [allowMultipartRequest] is true, then the Route is allowed to receive
/// multipart requests (file upload).
///
/// Example:
///
///     @Route('/user/:username', methods: const[GET, POST])
///     helloUser(String username) => "Hello, $username";
///
class Route implements RequestTarget {
  final String urlTemplate;

  final List<String> methods;

  final String responseType;

  final int statusCode;

  final bool allowMultipartRequest;

  final conv.Encoding encoding;

  const Route(this.urlTemplate, {this.methods: const [GET], this.responseType,
      this.statusCode: 200, this.allowMultipartRequest: false,
      this.encoding: conv.UTF8});
}

/// An annotation to define a target parameter.
///
/// The [type] is the type of the request body
///
/// Example:
///
///     @Route('/json_service/echo', methods: const[POST])
///     echoJson(@Body(JSON) Map json) => json;
///
class Body {
  final BodyType type;

  const Body(this.type);
}

/// An annotation to define a target parameter.
///
/// [name] is the name of the parameter.
///
/// Example:
///
///     @Route('/userInfo')
///     getUserInfo(@QueryParam('user') String user) {
///      ...
///     }
///
class QueryParam {
  final String name;

  const QueryParam([this.name]);
}

/// An annotation to define a request attribute.
///
/// [name] is the name of the request attribute
///
/// Example:
///
///     @Route('/service')
///     service(@Attr("conn") DbConn conn) {
///      ...
///     }
///
class Attr {
  final String name;

  const Attr([this.name]);
}

/// An annotation to define a injectable dependency.
///
/// Example:
///
///     @Route('/service')
///     service(@Inject() DbConn conn) {
///      ...
///     }
///
class Inject {
  const Inject();
}

/// An annotation to define interceptors.
///
/// The [urlPattern] is a regex that defines the requests that will be
/// intercepted. The [chainIdx] is the interceptor position in the chain.
/// If [parseRequestBody] is true, then the request body will be parsed
/// when the interceptor is invoked.
///
/// Example:
///
///     @Interceptor(r'/.*')
///     configureResponse() {
///       request.response.headers.add('Access-Control-Allow-Origin', '*');
///       chain.next();
///     }
///
class Interceptor {
  final String urlPattern;
  final int chainIdx;
  final bool parseRequestBody;

  const Interceptor(this.urlPattern,
      {this.chainIdx: 0, this.parseRequestBody: false});
}

/// An annotation to define error handlers.
///
/// [statusCode] is the HTTP status to be handled.
/// [urlPattern] is a regex that defines the requests
/// that will be handled.
///
/// Example:
///
///     @ErrorHandler(HttpStatus.NOT_FOUND)
///     handleNotFound() => redirect('/error_page/not_found.html');
///
class ErrorHandler {
  final int statusCode;
  final String urlPattern;

  const ErrorHandler(this.statusCode, {this.urlPattern});
}

/// An annotation to define groups.
///
/// [urlPrefix] is the url prefix of the group.
///
/// Example:
///
///     @Group('/user')
///     class UserService {
///
///       @Route('/find')
///       find() {
///         ...
///       }
///
///       @Route('/add')
///       add() {
///         ...
///       }
///
///       ...
///
///     }
///
class Group {
  final String urlPrefix;

  const Group(this.urlPrefix);
}

/// An annotation to define a target which must be bound
/// to the URL of its group.
///
/// If [pathSuffix] is provided, only requests that match
/// the suffix will be handled. [methods] are the HTTP
/// methods accepted by this target, and defaults to GET.
/// The [encoding] is the default encoding that will be used to
/// parse the request. The [responseType] is the content type
/// of the response. If it's not provided, the framework
/// will generate it based on the value returned by the method;
/// The [statusCode] is the default status of the response, and
/// defaults to 200. If [allowMultipartRequest]
/// is true, then the Route is allowed to receive multipart
/// requests (file upload).
class DefaultRoute implements RequestTarget {
  final String pathSuffix;

  final List<String> methods;

  final String responseType;

  final int statusCode;

  final bool allowMultipartRequest;

  final conv.Encoding encoding;

  const DefaultRoute({this.pathSuffix, this.methods: const [GET],
      this.responseType, this.statusCode: 200,
      this.allowMultipartRequest: false, this.encoding: conv.UTF8});
}

/// An annotation to include handlers from other libraries
class Install {
  final String urlPrefix;
  final int chainIdx;

  const Install({this.urlPrefix, this.chainIdx});
}

/// Use this annotation to import a library without installing
/// its handlers
class Ignore {
  const Ignore();
}
