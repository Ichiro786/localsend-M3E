import 'package:flutter_test/flutter_test.dart';
import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('startup retires the animation preference without changing unrelated settings', () async {
    SharedPreferences.setMockInitialValues({
      'ls_version': 3,
      'ls_locale': 'en',
      'ls_alias': 'My device',
      'ls_show_token': 'fixture-token',
      'ls_security_context': '{}',
      'ls_color': 'localsend',
      'ls_enable_animations': false,
      'ls_port': 54321,
    });
    final persistence = await PersistenceService.initialize(supportsDynamicColors: false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey('ls_enable_animations'), isFalse);
    expect(persistence.getAlias(), 'My device');
    expect(persistence.getPort(), 54321);
  });
}
