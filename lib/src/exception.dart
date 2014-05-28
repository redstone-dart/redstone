part of redstone_server;

class SetupException implements Exception {

  final String handler;
  final String message;

  SetupException(String this.handler, String this.message);

  String toString() => "SetupException: [$handler] $message";

}

class RequestException implements Exception {
  
  final String handler;
  final String message;
  final int statusCode;

  RequestException(String this.handler, String this.message, [int this.statusCode = 400]);

  String toString() => "RequestException($statusCode): [$handler] $message";
}

class ChainException implements Exception {
  
  final String urlPath;
  final String interceptorName;
  final String message;

  ChainException(String this.urlPath, String this.message, {String this.interceptorName});

  String toString() => message;

}