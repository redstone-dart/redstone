library redstone.src.http_mock;

//copied from http_server/test/http_mock.dart

import 'dart:io';
import 'dart:collection';
import 'dart:async';
import 'dart:convert';

class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _headers =
      new HashMap<String, List<String>>();

  ContentType _contentType;

  bool chunkedTransferEncoding;

  MockHttpHeaders([Map<String, List<String>> values]) {
    if (values != null) {
      _headers.addAll(values);
    }
  }

  List<String> operator [](String name) => _headers[name.toLowerCase()];

  DateTime get ifModifiedSince {
    List<String> values = _headers[HttpHeaders.IF_MODIFIED_SINCE];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  void set ifModifiedSince(DateTime ifModifiedSince) {
    // Format "ifModifiedSince" header with date in Greenwich Mean Time (GMT).
    String formatted = HttpDate.format(ifModifiedSince.toUtc());
    _set(HttpHeaders.IF_MODIFIED_SINCE, formatted);
  }

  DateTime get date {
    List<String> values = _headers[HttpHeaders.DATE];
    if (values != null) {
      try {
        return HttpDate.parse(values[0]);
      } on Exception {
        return null;
      }
    }
    return null;
  }

  void set date(DateTime date) {
    // Format "DateTime" header with date in Greenwich Mean Time (GMT).
    String formatted = HttpDate.format(date.toUtc());
    _set("date", formatted);
  }

  void set contentType(ContentType type) {
    if (_contentType == null && _headers["content-type"] == null) {
      _contentType = type;
      set("content-type", type.value);
    }
  }

  ContentType get contentType {
    if (_contentType != null) {
      return _contentType;
    }

    var ct = value("content-type");
    if (ct != null) {
      return ContentType.parse(ct);
    }
    return null;
  }

  void set(String name, Object value) {
    name = name.toLowerCase();
    _headers.remove(name);
    _addAll(name, value);
  }

  void add(String name, Object value) {
    name = name.toLowerCase();
    _addAll(name, value);
  }

  String value(String name) {
    name = name.toLowerCase();
    List<String> values = _headers[name];
    if (values == null) return null;
    if (values.length > 1) {
      throw new HttpException("More than one value for header $name");
    }
    return values.first;
  }

  void forEach(void f(String name, List<String> values)) => _headers.forEach(f);

  String toString() => '$runtimeType : $_headers';

  // [name] must be a lower-case version of the name.
  void _add(String name, value) {
    if (name == HttpHeaders.IF_MODIFIED_SINCE) {
      if (value is DateTime) {
        ifModifiedSince = value;
      } else if (value is String) {
        _set(HttpHeaders.IF_MODIFIED_SINCE, value);
      } else {
        throw new HttpException("Unexpected type for header named $name");
      }
    } else {
      _addValue(name, value);
    }
  }

  void _addAll(String name, value) {
    if (value is List) {
      for (int i = 0; i < value.length; i++) {
        _add(name, value[i]);
      }
    } else {
      _add(name, value);
    }
  }

  void _addValue(String name, Object value) {
    List<String> values = _headers[name];
    if (values == null) {
      values = new List<String>();
      _headers[name] = values;
    }
    if (value is DateTime) {
      values.add(HttpDate.format(value));
    } else {
      values.add(value.toString());
    }
  }

  void _set(String name, String value) {
    assert(name == name.toLowerCase());
    List<String> values = new List<String>();
    _headers[name] = values;
    values.add(value);
  }

  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class MockHttpResponse implements HttpResponse {
  final HttpHeaders headers = new MockHttpHeaders();
  final Completer _completer = new Completer();
  final List<int> _buffer = new List<int>();
  String _reasonPhrase;
  Future _doneFuture;

  MockHttpResponse() {
    _doneFuture = _completer.future.whenComplete(() {
      assert(!_isDone);
      _isDone = true;
    });
  }

  bool _isDone = false;

  int statusCode = HttpStatus.OK;

  String get reasonPhrase => _findReasonPhrase(statusCode);

  void set reasonPhrase(String value) {
    _reasonPhrase = value;
  }

  Future get done => _doneFuture;

  Future close() {
    _completer.complete();
    return _doneFuture;
  }

  void add(List<int> data) {
    _buffer.addAll(data);
  }

  Future addStream(Stream<List<int>> stream) {
    var completer = new Completer();
    stream.listen((data) {
      _buffer.addAll(data);
    }, onDone: () => completer.complete());

    return completer.future;
  }

  void addError(dynamic error, [StackTrace stackTrace]) {
    // doesn't seem to be hit...hmm...
  }

  Future redirect(Uri location, {int status: HttpStatus.MOVED_TEMPORARILY}) {
    this.statusCode = status;
    headers.set(HttpHeaders.LOCATION, location.toString());
    return close();
  }

  void write(Object obj) {
    var str = obj.toString();
    add(UTF8.encode(str));
  }

  Future<Socket> detachSocket({bool writeHeaders: true}) {
    throw "MockHttpResponse.detachSocket: Unsupported Operation";
  }

  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  String get mockContent => UTF8.decode(_buffer);

  bool get mockDone => _isDone;

  // Copied from SDK http_impl.dart @ 845 on 2014-01-05
  // TODO: file an SDK bug to expose this on HttpStatus in some way
  String _findReasonPhrase(int statusCode) {
    if (_reasonPhrase != null) {
      return _reasonPhrase;
    }

    switch (statusCode) {
      case HttpStatus.NOT_FOUND:
        return "Not Found";
      default:
        return "Status $statusCode";
    }
  }
}

class MockHttpRequest extends Stream<List<int>> implements HttpRequest {
  final Uri requestedUri;
  final Uri uri;

  final MockHttpResponse response = new MockHttpResponse();
  final HttpHeaders headers;
  final String method;
  final bool followRedirects;
  final HttpSession session;
  final Stream<List<int>> body;

  MockHttpRequest(
      this.requestedUri, this.uri, this.method, this.headers, this.body,
      {this.session, this.followRedirects: true, DateTime ifModifiedSince}) {
    if (ifModifiedSince != null) {
      headers.ifModifiedSince = ifModifiedSince;
    }
  }

  @override
  StreamSubscription<List<int>> listen(void onData(List<int> event),
      {Function onError, void onDone(), bool cancelOnError}) {
    return body.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  int get contentLength => -1;

  @override
  String get protocolVersion => "1.1";

  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}
