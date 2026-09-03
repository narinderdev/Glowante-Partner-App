import 'package:bloc_onboarding/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app widget can be constructed', () {
    const app = MyApp();

    expect(app, isA<MyApp>());
  });
}
