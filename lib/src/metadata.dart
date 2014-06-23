part of redstone_server;

/**
 * An annotation to define targets.
 *
 * [urlTemplate] is the url of the target, and can contains arguments prefixed with ':'.
 * [methods] are the HTTP methods accepted by this target, and defaults to GET.
 * The [responseType] is the content type of the response. If it's not provided,
 * the framework will generate it based on the value returned by the method;
 * If [allowMultipartRequest] is true, then the Route is allowed to receive
 * multipart requests (file upload).
 *
 * Example:
 *
 *     @app.Route('/user/:username', methods: const[app.GET, app.POST])
 *     helloUser(String username) => "Hello, $username";
 *
 */
class Route {

  final String urlTemplate;

  final List<String> methods;

  final String responseType;

  final bool allowMultipartRequest;

  final bool matchSubPaths;

  const Route(this.urlTemplate,
              {this.methods: const [GET],
               this.responseType,
               this.allowMultipartRequest: false,
               this.matchSubPaths: false});

  Route.conf(this.urlTemplate,
             {this.methods: const [GET],
              this.responseType,
              this.allowMultipartRequest: false,
              this.matchSubPaths: false});

}

/**
 * An annotation to define a target parameter.
 *
 * The [type] is the type of the request body
 *
 * Example:
 *
 *     @app.Route('/json_service/echo', methods: const[app.POST])
 *     echoJson(@app.Body(app.JSON) Map json) => json;
 *
 */
class Body {

  final String type;

  const Body(this.type);

}

/**
 * An annotation to define a target parameter.
 *
 * [name] is the name of the parameter.
 *
 * Example:
 *
 *     @app.Route('/userInfo')
 *     getUserInfo(@app.QueryParam('user') String user) {
 *      ...
 *     }
 *
 */
class QueryParam {

  final String name;

  const QueryParam([this.name]);
}

/**
 * An annotation to define a target parameter.
 *
 * [name] is the name of the request attribute
 *
 * Example:
 *
 *     @app.Route('/service')
 *     service(@app.Attr("conn") DbConn conn) {
 *      ...
 *     }
 *
 */
class Attr {

  final String name;

  const Attr([this.name]);
}

/**
 * An annotation to define a target parameter.
 *
 * Example:
 *
 *     @app.Route('/service')
 *     service(@app.Inject() DbConn conn) {
 *      ...
 *     }
 *
 */
class Inject {

  const Inject();

}

/**
 * An annotation to define interceptors.
 *
 * The [urlPattern] is a regex that defines the requests that will be
 * intercepted. The [chainIdx] is the interceptor position in the chain.
 * If [parseRequestBody] is true, then the request body will be parsed
 * when the interceptor is invoked.
 *
 * Example:
 *
 *     @app.Interceptor(r'/.*')
 *     configureResponse() {
 *       app.request.response.headers.add('Access-Control-Allow-Origin', '*');
 *       app.chain.next();
 *     }
 *
 */
class Interceptor {

  final String urlPattern;
  final int chainIdx;
  final bool parseRequestBody;

  const Interceptor(this.urlPattern, {this.chainIdx: 0, this.parseRequestBody: false});

  Interceptor.conf(this.urlPattern, {this.chainIdx: 0, this.parseRequestBody: false});

}

/**
 * An annotation to define error handlers.
 *
 * [statusCode] is the HTTP status to be handled.
 * [urlPattern] is a regex that defines the requests
 * that will be handled.
 *
 * Example:
 *
 *     @app.ErrorHandler(HttpStatus.NOT_FOUND)
 *     handleNotFound() => app.redirect('/error_page/not_found.html');
 *
 */
class ErrorHandler {

  final int statusCode;
  final String urlPattern;

  const ErrorHandler(this.statusCode, {this.urlPattern});

  ErrorHandler.conf(this.statusCode, {this.urlPattern});

}

/**
 * An annotation to define groups.
 *
 * [urlPrefix] is the url prefix of the group.
 *
 * Example:
 *
 *     @app.Group('/user')
 *     class UserService {
 *
 *       @app.Route('/find')
 *       find() {
 *         ...
 *       }
 *
 *       @app.Route('/add')
 *       add() {
 *         ...
 *       }
 *
 *       ...
 *
 *     }
 *
 */
class Group {

  final String urlPrefix;

  const Group(this.urlPrefix);

}

/**
 * An annotation to define a target which must be bound
 * to the URL of its group.
 *
 * If [pathSuffix] is provided, only requests that match
 * the suffix will be handled. [methods] are the HTTP
 * methods accepted by this target, and defaults to GET.
 * The [responseType] is the content type of the response.
 * If it's not provided, the framework will generate it based on
 * the value returned by the method; If [allowMultipartRequest]
 * is true, then the Route is allowed to receive multipart
 * requests (file upload).
 *
 */
class DefaultRoute {

  final String pathSuffix;

  final List<String> methods;

  final String responseType;

  final bool allowMultipartRequest;

  final bool matchSubPaths;

  const DefaultRoute({this.pathSuffix,
                      this.methods: const [GET],
                      this.responseType, this.allowMultipartRequest: false,
                      this.matchSubPaths: false});
}

/**
 * An annotation to include handlers from other libraries
 *
 */
class Install {

  final String urlPrefix;
  final int chainIdx;

  const Install({this.urlPrefix, this.chainIdx});

  Install.conf({this.urlPrefix, this.chainIdx});

  Install.defaultConf() :
    urlPrefix = null,
    chainIdx = null;
}

/**
 * Use this annotation to import a library without installing
 * its handlers
 */
class Ignore {

  const Ignore();

}