import 'package:flutter_test/flutter_test.dart';

import 'package:umami_flutter/umami_flutter.dart';

void main() {
  test('Umami instance should be a singleton', () {
    final umami1 = Umami();
    final umami2 = Umami();

    expect(umami1, equals(umami2));
  });
}
