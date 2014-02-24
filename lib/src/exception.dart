part of bloodless_server;

class SetupException implements Exception {

  final String handler;
  final String message;

  SetupException(String this.handler, String this.message);

  String toString() => "SetupException: [$handler] $message";

}

class RequestException implements Exception {
  
  final String handler;
  final String message;

  RequestException(String this.handler, String this.message);

  String toString() => "RequestException: [$handler] $message";
}

class ChainException implements Exception {
  
  final String urlPath;
  final String interceptorName;
  final String message;

  ChainException(String this.urlPath, String this.message, {String this.interceptorName});

  String toString() => message;

}