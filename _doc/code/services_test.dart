import 'package:test/test.dart';
import 'package:redstone/redstone.dart' as app;
import 'package:your_package_name/services.dart';

main() {
  // Load handlers in 'services' library
  setUp(() => app.redstoneSetUp([#services]));

  // Remove all loaded handlers
  tearDown(() => app.redstoneTearDown());

  test("hello service", () {
    // Create a mock request
    var req = new app.MockRequest("/user/luiz");
    // Dispatch the request
    return app.dispatch(req).then((resp) {
      // Verify the response
      expect(resp.statusCode, equals(200));
      expect(resp.mockContent, equals("hello, luiz"));
    });
  });
}