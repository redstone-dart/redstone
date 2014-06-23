part of redstone_server;

class SetupException implements Exception {

  final String handler;
  final String message;

  SetupException(this.handler, this.message);

  String toString() => "SetupException: [$handler] $message";

}

class RequestException implements Exception {

  final String handler;
  final String message;
  final int statusCode;

  RequestException(this.handler, this.message, [this.statusCode = 400]);

  String toString() => "RequestException($statusCode): [$handler] $message";
}

class ChainException implements Exception {

  final String urlPath;
  final String interceptorName;
  final String message;

  ChainException(this.urlPath, this.message, {this.interceptorName});

  String toString() => message;

}