library dartdoc_viewer.web.index_html_0;

    import 'package:polymer/polymer.dart' show initMethod;
    import 'package:dartdoc_viewer/app.dart' show initApp;
    // TODO(sigmund): ideally using 'export' should work, but for some reason
    // polymer's bootstrap is not picking up exported initMethods.
    @initMethod main() => initApp();
  