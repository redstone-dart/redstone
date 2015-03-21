library redstone.src.constants;

///HTTP methods
const String GET = "GET";
const String POST = "POST";
const String PUT = "PUT";
const String DELETE = "DELETE";
const String OPTIONS = "OPTIONS";
const String HEAD = "HEAD";
const String TRACE = "TRACE";
const String CONNECT = "CONNECT";

///Content types
enum BodyType { JSON, FORM, TEXT, BINARY }

const BodyType JSON = BodyType.JSON;
const BodyType FORM = BodyType.FORM;
const BodyType TEXT = BodyType.TEXT;
const BodyType BINARY = BodyType.BINARY;
