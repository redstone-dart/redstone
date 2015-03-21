library redstone.src.dynamic_map;

import 'dart:mirrors';

import 'package:collection/collection.dart' show DelegatingMap, DelegatingList;

/// A Map that allows the use of the dot notation to access
/// its values
///
/// Usage:
///
///      DynamicMap map = new DynamicMap({"key": "value"});
///      print(map.key); //prints 'value'
@proxy
class DynamicMap<K, V> extends DelegatingMap {
  DynamicMap(Map<K, V> map) : super(map);

  ///Retrieve a value from this map
  V get(K key, [V defaultValue]) {
    if (containsKey(key)) {
      var value = this[key];
      if (value is! DynamicMap && value is Map) {
        value = new DynamicMap(value);
        this[key] = value;
      } else if (value is! _ListWrapper && value is List) {
        value = new _ListWrapper.wrap(value);
        this[key] = value;
      }
      return value;
    } else if (defaultValue != null) {
      return defaultValue;
    }
    return null;
  }

  noSuchMethod(Invocation invocation) {
    var key = MirrorSystem.getName(invocation.memberName);
    if (invocation.isGetter) {
      return get(key);
    } else if (invocation.isSetter) {
      this[key.substring(0, key.length - 1)] =
          invocation.positionalArguments.first;
    } else {
      super.noSuchMethod(invocation);
    }
  }
}

class _ListWrapper extends DelegatingList {
  _ListWrapper(List list) : super(list);

  factory _ListWrapper.wrap(List list) {
    list = list.map((e) {
      if (e is Map && e is! DynamicMap) {
        return new DynamicMap(e);
      } else if (e is List && e is! _ListWrapper) {
        return new _ListWrapper.wrap(e);
      }
      return e;
    }).toList();
    return new _ListWrapper(list);
  }
}
