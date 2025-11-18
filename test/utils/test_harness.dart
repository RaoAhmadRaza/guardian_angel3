import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer makeContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

void disposeContainer(ProviderContainer container) {
  container.dispose();
}
