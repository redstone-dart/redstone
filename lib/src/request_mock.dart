library redstone.src.request_mock;

import 'dart:io';
import 'dart:convert' as conv;
import 'dart:async';

import 'package:crypto/crypto.dart';

import 'package:collection/collection.dart' show DelegatingMap;
import 'package:http/http.dart' as http;
import 'package:http/src/utils.dart';
import 'package:http_parser/src/media_type.dart';
import 'package:http_server/src/http_body.dart';

import 'http_mock.dart';
import 'request.dart';
import 'request_parser.dart';
import 'constants.dart';

/// A class to simulate requests in unit tests.
///
/// Usage:
///
///     var req = new MockRequest("/service");
///     app.dispatch(req).then((resp) {
///       ...
///     });
///
class MockRequest extends RequestParser {
  factory MockRequest(String path, {String method: GET, String scheme: "http",
      String host: "localhost", int port: 8080,
      Map<String, dynamic> queryParameters, BodyType bodyType: BINARY,
      dynamic body, String contentType, bool isMultipart: false,
      Map<String, String> headers, Credentials basicAuth,
      HttpSession session}) {
    if (headers == null) {
      headers = {};
    }
    var bodyStream =
        _handleBody(bodyType, body, contentType, isMultipart, headers);

    var hValues = {};
    headers.forEach((k, v) => hValues[k] = [v]);

    if (basicAuth != null) {
      String auth = CryptoUtils.bytesToBase64(
          conv.UTF8.encode("${basicAuth.username}:${basicAuth.password}"));
      hValues[HttpHeaders.AUTHORIZATION] = ["Basic $auth"];
    }

    var _httpHeaders = new MockHttpHeaders(hValues);

    String query = null;
    if (queryParameters != null) {
      StringBuffer queryBuffer = new StringBuffer();
      queryParameters.forEach((key, value) {
        if (value is List) {
          value.forEach((v) => queryBuffer.write("$key=$v&"));
        } else {
          queryBuffer.write("$key=$value&");
        }
      });
      query = queryBuffer.toString().substring(0, queryBuffer.length - 1);
    }

    Uri requestedUri = new Uri(
        scheme: scheme, host: host, port: port, path: path, query: query);
    Uri uri = new Uri(path: path);
    var httpRequest = new MockHttpRequest(
        requestedUri, uri, method, _httpHeaders, bodyStream, session: session);

    return new MockRequest.fromMockRequest(httpRequest);
  }

  MockRequest.fromMockRequest(MockHttpRequest mockRequest) : super(mockRequest);
}

/// A mock session, intended to be used
/// with [MockRequest].
///
/// Usage:
///
///     var session = new MockHttpSession("session_1", {"username": "user"});
///     var req = new MockRequest("/service", session: session);
///     app.dispatch(req).then((resp) {
///       ...
///     });
///
class MockHttpSession extends DelegatingMap implements HttpSession {
  final String id;

  Function _timeoutCallback;
  bool _destroyed = false;

  MockHttpSession(this.id, {Map<String, String> values})
      : super(values == null ? {} : values);

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

Stream<List<int>> _handleBody(BodyType bodyType, dynamic body,
    String contentType, bool isMultipart, Map<String, String> headerValues) {
  var serializedBody = const [];
  if (body == null) {
    return new Stream.fromIterable(serializedBody);
  }
  switch (bodyType) {
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
            m.files.add(new http.MultipartFile(key,
                new Stream.fromIterable([value.content]), value.content.length,
                filename: value.filename,
                contentType: new MediaType.parse(value.contentType.mimeType)));
          } else {
            m.fields[key] = value.toString();
          }
        });
        var stream = m.finalize();
        headerValues.addAll(m.headers);
        return stream;
      } else {
        headerValues["content-type"] = contentType != null
            ? contentType
            : "application/x-www-form-urlencoded";
        serializedBody =
            conv.UTF8.encode(mapToQuery(body, encoding: conv.UTF8));
      }
      break;
    default:
      serializedBody = conv.UTF8.encode(body.toString());
  }

  return new Stream.fromIterable([serializedBody]);
}
