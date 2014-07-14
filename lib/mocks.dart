library redstone_mocks;

import 'dart:io';
import 'dart:collection';
import 'dart:convert' as conv;
import 'dart:async';

import 'package:crypto/crypto.dart';

import 'package:collection/collection.dart' show DelegatingMap;
import 'package:redstone/server.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:http/http.dart' as http;
import 'package:http/src/utils.dart';
import 'package:http_parser/src/media_type.dart';

import 'query_map.dart';

part 'src/http_mock.dart';

/**
 * A class to simulate requests in unit tests.
 *
 * Usage:
 *
 *     var req = new MockRequest("/service");
 *     app.dispatch(req).then((resp) {
 *       ...
 *     });
 */
class MockRequest extends HttpRequestParser implements UnparsedRequest {

  final Map _attributes = new QueryMap({});

  Future _parsedBody;

  HttpHeaders _httpHeaders;
  HttpResponse _response;
  HttpRequest httpRequest;

  shelf.Request _shelfRequest;

  QueryMap _headers = null;
  QueryMap _queryParams = null;

  shelf.Request get shelfRequest => _shelfRequest;

  set shelfRequest(shelf.Request shelfRequest) {
    _shelfRequest = shelfRequest;
    _headers = new QueryMap(shelfRequest.headers);
    _queryParams = new QueryMap(shelfRequest.url.queryParameters);
  }

  final HttpSession session;

  MockRequest(String path, {String method: GET,
              String scheme: "http", String host: "localhost",
              int port: 8080, Map<String, String> queryParams: const {},
              String bodyType: BINARY, dynamic body, String contentType,
              bool isMultipart: false,
              Map<String, String> headers,
              Credentials basicAuth,
              this.session}) {

    if (headers == null) {
      headers = {};
    }
    var bodyStream = _handleBody(bodyType, body, contentType, isMultipart, headers);

    var hValues = {};
    headers.forEach((k, v) => hValues[k] = [v]);

    if (basicAuth != null) {
      String auth = CryptoUtils.bytesToBase64(
          conv.UTF8.encode("${basicAuth.username}:${basicAuth.password}"));
      hValues[HttpHeaders.AUTHORIZATION] = ["Basic $auth"];
    }

    _httpHeaders = new MockHttpHeaders(hValues);

    Uri requestedUri = new Uri(scheme: scheme, host: host, port: port,
        path: path, queryParameters: queryParams);
    Uri uri = new Uri(path: path);
    httpRequest = new MockHttpRequest(requestedUri, uri, method, _httpHeaders, bodyStream, session: session);
    _response = httpRequest.response;

  }

  Stream<List<int>> _handleBody(String bodyType, dynamic body,
      String contentType, bool isMultipart, Map<String, String> headerValues) {
    var serializedBody = const [];
    if (body == null) {
      return new Stream.fromIterable(serializedBody);
    }
    switch(bodyType) {
      case JSON:
        headerValues["content-type"] =
          contentType != null ? contentType : "application/json";
        serializedBody = conv.UTF8.encode(conv.JSON.encode(body));
        break;
      case TEXT:
        headerValues["content-type"] =
          contentType != null ? contentType : "text/plain";
        serializedBody = conv.UTF8.encode(body.toString());
        break;
      case FORM:
        if (isMultipart) {
          var m = new http.MultipartRequest("POST", new Uri());
          (body as Map).forEach((String key, value) {
            if (value is HttpBodyFileUpload) {
              m.files.add(new http.MultipartFile(
                  key, new Stream.fromIterable([value.content]),
                      value.content.length, filename: value.filename,
                        contentType: new MediaType.parse(value.contentType.mimeType)));
            } else {
              m.fields[key] = value.toString();
            }
          });
          var stream = m.finalize();
          headerValues.addAll(m.headers);
          return stream;
        } else {
          headerValues["content-type"] =
            contentType != null ? contentType : "application/x-www-form-urlencoded";
          serializedBody = conv.UTF8.encode(mapToQuery(body, encoding: conv.UTF8));
        }
        break;
      default:
        serializedBody = conv.UTF8.encode(body.toString());
    }

    return new Stream.fromIterable([serializedBody]);
  }

  Uri get requestedUri => shelfRequest.requestedUri;

  Uri get url => shelfRequest.url;

  String get method => shelfRequest.method;

  QueryMap get queryParams => _queryParams;

  QueryMap get headers => _headers;

  HttpResponse get response => _response;

  QueryMap get attributes => _attributes;

  void parseBodyType() => parseHttpRequestBodyType(headers);

  Future parseBody() => parseHttpRequestBody(shelfRequest.read());

}

/**
 * A mock session, intended to be used
 * with [MockRequest].
 *
 * Usage:
 *
 *     var session = new MockHttpSession("session_1", {"username": "user"});
 *     var req = new MockRequest("/service", session: session);
 *     app.dispatch(req).then((resp) {
 *       ...
 *     });
 *
 */
class MockHttpSession extends DelegatingMap implements HttpSession {

  final String id;

  Function _timeoutCallback;
  bool _destroyed = false;

  MockHttpSession(this.id, {Map<String, String> values}) : super(values == null ? {} : values);

  void destroy() {
    _destroyed = true;
  }

  bool get destroyed => _destroyed;

  void set onTimeout(void callback()) {
    _timeoutCallback = callback;
  }

  Function get timeoutCallback => _timeoutCallback;

  bool get isNew => false;

  set isNew(bool value) => isNew = value;

}