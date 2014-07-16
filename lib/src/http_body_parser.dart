part of redstone_server;

///ported from the http_server package
///http://pub.dartlang.org/packages/http_server

/// A form item that contains a file.
class HttpBodyFileUpload {
  final ContentType contentType;
  final String filename;
  final List<int> content;

  HttpBodyFileUpload(this.contentType, this.filename, this.content);

}

/**
 * The body of a HTTP request.
 *
 * [type] can be 'binary', 'text', 'form' and 'json'.
 * [body] can be a List, Map or String.
 */
class HttpBody {
  final String type;
  final dynamic body;

  HttpBody(this.type, this.body);
}

Future<HttpBody> _parseRequestBody(Stream<List<int>> stream,
                                  ContentType contentType,
                                  {conv.Encoding defaultEncoding: conv.UTF8}) {

  Future<HttpBody> asBinary() {
    return stream
        .fold(new BytesBuilder(), (builder, data) => builder..add(data))
        .then((builder) => new HttpBody(BINARY, builder.takeBytes()));
  }

  Future<HttpBody> asText(conv.Encoding defaultEncoding) {
    var encoding;
    var charset = contentType.charset;
    if (charset != null) encoding = conv.Encoding.getByName(charset);
    if (encoding == null) encoding = defaultEncoding;
    return stream
        .transform(encoding.decoder)
        .fold(new StringBuffer(), (buffer, data) => buffer..write(data))
        .then((buffer) => new HttpBody(TEXT, buffer.toString()));
  }

  Future<HttpBody> asFormData() {
    return stream
        .transform(new MimeMultipartTransformer(
              contentType.parameters['boundary']))
        .map((part) => _HttpMultipartFormData.parse(
              part, defaultEncoding))
        .map((_HttpMultipartFormData multipart) {
          var future;
          if (multipart.isText) {
            future = multipart
                .fold(new StringBuffer(), (b, s) => b..write(s))
                .then((b) => b.toString());
          } else {
            future = multipart
                .fold(new BytesBuilder(), (b, d) => b..add(d))
                .then((b) => b.takeBytes());
          }
          return future.then((data) {
            var filename =
                multipart.contentDisposition.parameters['filename'];
            if (filename != null) {
              data = new HttpBodyFileUpload(multipart.contentType,
                                             filename,
                                             data);
            }
            return [multipart.contentDisposition.parameters['name'], data];
          });
        })
        .fold([], (l, f) => l..add(f))
        .then(Future.wait)
        .then((parts) {
          Map<String, dynamic> map = new Map<String, dynamic>();
          for (var part in parts) {
            map[part[0]] = part[1];  // Override existing entries.
          }
          return new HttpBody(FORM, map);
        });
  }

  if (contentType == null) {
    return asBinary();
  }

  switch (contentType.primaryType) {
    case "text":
      return asText(defaultEncoding);

    case "application":
      switch (contentType.subType) {
        case "json":
          return asText(conv.UTF8)
              .then((body) => new HttpBody(JSON, conv.JSON.decode(body.body)));

        case "x-www-form-urlencoded":
          return asText(conv.ASCII)
              .then((body) {
                var map = Uri.splitQueryString(body.body,
                    encoding: defaultEncoding);
                return new HttpBody(FORM, new Map.from(map));
              });

        default:
          break;
      }
      break;

    case "multipart":
      switch (contentType.subType) {
        case "form-data":
          return asFormData();

        default:
          break;
      }
      break;

    default:
      break;
  }

  return asBinary();
}

class _HttpMultipartFormData extends Stream {
  final ContentType contentType;
  final HeaderValue contentDisposition;
  final HeaderValue contentTransferEncoding;

  final MimeMultipart _mimeMultipart;

  bool _isText = false;

  Stream _stream;

  _HttpMultipartFormData(ContentType this.contentType,
                         HeaderValue this.contentDisposition,
                         HeaderValue this.contentTransferEncoding,
                         MimeMultipart this._mimeMultipart,
                         conv.Encoding defaultEncoding) {
    _stream = _mimeMultipart;
    if (contentTransferEncoding != null) {
      throw new HttpException("Unsupported contentTransferEncoding: "
                              "${contentTransferEncoding.value}");
    }

    if (contentType == null ||
        contentType.primaryType == 'text' ||
        contentType.mimeType == 'application/json') {
      _isText = true;
      StringBuffer buffer = new StringBuffer();
      conv.Encoding encoding;
      if (contentType != null) {
        encoding = conv.Encoding.getByName(contentType.charset);
      }
      if (encoding == null) encoding = defaultEncoding;
      _stream = _stream
          .transform(encoding.decoder)
          .expand((data) {
            buffer.write(data);
            var out = _decodeHttpEntityString(buffer.toString());
            if (out != null) {
              buffer.clear();
              return [out];
            }
            return const [];
          });
    }
  }

  bool get isText => _isText;
  bool get isBinary => !_isText;

  static _HttpMultipartFormData parse(MimeMultipart multipart,
                                     conv.Encoding defaultEncoding) {
    var type;
    var encoding;
    var disposition;
    var remaining = new Map<String, String>();
    for (String key in multipart.headers.keys) {
      switch (key) {
        case 'content-type':
          type = ContentType.parse(multipart.headers[key]);
          break;

        case 'content-transfer-encoding':
          encoding = HeaderValue.parse(multipart.headers[key]);
          break;

        case 'content-disposition':
          disposition = HeaderValue.parse(multipart.headers[key],
                                          preserveBackslash: true);
          break;

        default:
          remaining[key] = multipart.headers[key];
          break;
      }
    }
    if (disposition == null) {
      throw new HttpException(
          "Mime Multipart doesn't contain a Content-Disposition header value");
    }
    return new _HttpMultipartFormData(
        type, disposition, encoding, multipart, defaultEncoding);
  }

  StreamSubscription listen(void onData(data),
                            {void onDone(),
                             Function onError,
                             bool cancelOnError}) {
    return _stream.listen(onData,
                          onDone: onDone,
                          onError: onError,
                          cancelOnError: cancelOnError);
  }

  String value(String name) =>_mimeMultipart.headers[name];

  // Decode a string with HTTP entities. Returns null if the string ends in the
  // middle of a http entity.
  static String _decodeHttpEntityString(String input) {
    int amp = input.lastIndexOf('&');
    if (amp < 0) return input;
    int end = input.lastIndexOf(';');
    if (end < amp) return null;

    var buffer = new StringBuffer();
    int offset = 0;

    parse(amp, end) {
      switch (input[amp + 1]) {
        case '#':
          if (input[amp + 2] == 'x') {
            buffer.writeCharCode(
                int.parse(input.substring(amp + 3, end), radix: 16));
          } else {
            buffer.writeCharCode(int.parse(input.substring(amp + 2, end)));
          }
          break;

        default:
          throw new HttpException('Unhandled HTTP entity token');
      }
    }

    while ((amp = input.indexOf('&', offset)) >= 0) {
      buffer.write(input.substring(offset, amp));
      int end = input.indexOf(';', amp);
      parse(amp, end);
      offset = end + 1;
    }
    buffer.write(input.substring(offset));
    return buffer.toString();
  }
}