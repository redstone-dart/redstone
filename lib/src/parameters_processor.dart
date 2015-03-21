library redstone.src.parameters_processor;

import 'dart:async';
import 'dart:mirrors';

import 'package:di/di.dart';

import 'metadata.dart';
import 'server_metadata.dart';
import 'request_context.dart';
import 'request.dart';

typedef dynamic Converter(String value);
typedef dynamic ArgHandler(Request request, Converter converter);
typedef ArgHandler ParamHandler(String handlerName, Injector injector,
    Object metadata, ParameterMirror mirror);

const ParamHandler ATTRIBUTE_HANDLER = const AttributeHandler();
const ParamHandler DI_HANDLER = const DiHandler();

final intType = reflectClass(int);
final doubleType = reflectClass(double);
final numType = reflectClass(num);
final boolType = reflectClass(bool);
final stringType = reflectClass(String);
final listType = reflectClass(List);
final dynamicType = reflectType(dynamic);
final voidType = currentMirrorSystem().voidType;

/// A [ParametersProcessor] is responsible for
/// mapping request information (such as query parameters,
/// body data and attributes) to handlers arguments.
class ParametersProcessor implements Function {
  final String handlerName;
  final List<ParameterMirror> parameters;
  final Injector injector;
  final Map<Type, ParamProvider> providers;

  final Map<Type, ParamHandler> _metadataHandlers = {};
  final List<Function> _paramProcessors = [];

  ParamHandler _defaultParamHandler;
  ArgHandler _defaultArgHandler;

  ParametersProcessor(
      this.handlerName, this.parameters, this.injector, this.providers,
      [this._defaultParamHandler]) {
    if (_defaultParamHandler == null) {
      _defaultArgHandler = (r, c) => null;
    }
  }

  void addDefaultMetadataHandlers() {
    _metadataHandlers[Attr] = ATTRIBUTE_HANDLER;
    _metadataHandlers[Inject] = DI_HANDLER;
  }

  void addMetadataHandler(Type type, ParamHandler handler) {
    _metadataHandlers[type] = handler;
  }

  Future call(Request request, List positionalArgs, Map namedArgs) {
    return Future.forEach(
        _paramProcessors, (p) => p(request, positionalArgs, namedArgs));
  }

  void build() {
    parameters.forEach((ParameterMirror param) {
      var paramSymbol = param.simpleName;
      var isNamed = param.isNamed;
      var name = MirrorSystem.getName(paramSymbol);
      var type = param.type;
      var defaultValue =
          param.defaultValue != null ? param.defaultValue.reflectee : null;
      var converter = getValueConverter(type);
      ParamProvider provider = null;

      var metadata = null;
      var argHandler = null;
      if (!param.metadata.isEmpty) {
        metadata = param.metadata[0].reflectee;
        var metadataProcessor = _metadataHandlers[metadata.runtimeType];

        if (metadataProcessor != null) {
          argHandler =
              metadataProcessor(handlerName, injector, metadata, param);
        } else {
          provider = providers[metadata.runtimeType];
          if (provider != null) {
            argHandler = (Request req, _) async {
              var value = await provider(metadata, type.reflectedType,
                  handlerName, name, req, injector);
              return value != null ? value : defaultValue;
            };
          }
        }
      }

      if (argHandler == null) {
        if (_defaultArgHandler != null) {
          argHandler = _defaultArgHandler;
        } else {
          argHandler = _defaultParamHandler(handlerName, injector, null, param);
        }
      }

      var processor = (Request request, List positionalArgs,
          Map namedArgs) async {
        var value = await argHandler(request, converter);
        if (value == null) {
          value = defaultValue;
        }
        if (isNamed) {
          namedArgs[paramSymbol] = value;
        } else {
          positionalArgs.add(value);
        }
      };

      _paramProcessors.add(processor);
    });
  }
}

class AttributeHandler implements Function {
  const AttributeHandler();

  ArgHandler call(String handlerName, Injector injector, Object metadata,
      ParameterMirror mirror) {
    var attr = (metadata as Attr);
    String name = MirrorSystem.getName(mirror.simpleName);
    var key = attr.name != null ? attr.name : name;
    return (Request request, Converter converter) => request.attributes[key];
  }
}

class DiHandler implements Function {
  const DiHandler();

  ArgHandler call(String handlerName, Injector injector, Object metadata,
      ParameterMirror mirror) {
    var value;
    try {
      value = injector.get(mirror.type.reflectedType);
    } catch (e) {
      var name = MirrorSystem.getName(mirror.simpleName);
      throw new SetupException(
          handlerName, "Invalid parameter: Can't inject $name");
    }

    return (Request request, Converter converter) => value;
  }
}

dynamic convertValue(
    Converter converter, String paramName, String value, String handlerName) {
  try {
    return converter(value);
  } catch (e) {
    throw new RequestException(
        handlerName, "Invalid value for parameter '$paramName': $value");
  }
}

Converter getValueConverter(dynamic paramType) {
  if (paramType == stringType || paramType == dynamicType) {
    return (String value) => value;
  }
  if (paramType == intType) {
    return (String value) => int.parse(value);
  }
  if (paramType == doubleType) {
    return (String value) => double.parse(value);
  }
  if (paramType == numType) {
    return (String value) => num.parse(value);
  }
  if (paramType == boolType) {
    return (String value) => value.toLowerCase();
  }

  return (String value) => null;
}
