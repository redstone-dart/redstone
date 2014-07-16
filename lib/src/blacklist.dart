part of redstone_server;

//do not scan the following libraries
var _blacklist = const [

  #dart.core,
  #dart.async,
  #dart.collection,
  #dart.convert,
  #dart.html,
  #dart.indexed_db,
  #dart.io,
  #dart.isolate,
  #dart.js,
  #dart.math,
  #dart.mirrors,
  #dart.svg,
  #dart.typed_data,
  #dart.web_audio,
  #dart.web_gl,
  #dart.web_sql

];

Set<Symbol> _buildBlacklistSet() => new Set<Symbol>.from(_blacklist);
