import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_angel_fyp/persistence/wrappers/box_accessor.dart';

/// Unit tests for BoxAccessor
void main() {
  group('BoxAccessor', () {
    test('throws StateError when box not open', () {
      final accessor = BoxAccessor();
      
      // Attempting to access a box that isn't open should throw
      expect(
        () => accessor.pendingOps(),
        throwsStateError,
      );
    });

    test('isOpen returns false for closed box', () {
      final accessor = BoxAccessor();
      
      expect(accessor.isOpen('nonexistent_box'), isFalse);
    });

    test('safeBox returns null for closed box', () {
      final accessor = BoxAccessor();
      
      final box = accessor.safeBox<String>('nonexistent_box');
      expect(box, isNull);
    });
  });
}
