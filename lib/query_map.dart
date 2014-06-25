library redstone_query_map;

import 'dart:mirrors';

import 'package:collection/collection.dart' show DelegatingMap;

/**
 * A Map that allows the use of the dot notation to access
 * its values
 * 
 * Usage:
 * 
 *      QueryMap<String, String> map = new QueryMap({"key": "value"});
 *      print(map.key); //prints 'value'
 */
@proxy
class QueryMap<V> extends DelegatingMap<String, V> {
  
  QueryMap(Map map) : super(map);
  
  ///Retrieve a value from this map
  V get(String key, [V defaultValue]) {
    if(containsKey(key)) {
      var value = this[key];
      if (value is! QueryMap && value is Map) {
        value = new QueryMap(value);
        this[key] = value as V;
      }
      return value;
    } else if(defaultValue != null) {
      return defaultValue;
    }
    return null;
  }
  
  noSuchMethod(Invocation invocation) {
    var key = MirrorSystem.getName(invocation.memberName);
    if (invocation.isGetter) {
      return get(key);
    } else if (invocation.isSetter) {
      this[key.substring(key.length - 1)] = invocation.positionalArguments.first;
    } else {
      super.noSuchMethod(invocation);
    }
  }
}