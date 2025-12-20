import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guardian_angel_fyp/widgets/conflict_resolution_dialog.dart';

/// Unit and widget tests for ConflictResolutionDialog
void main() {
  group('ConflictChoice', () {
    test('enum values', () {
      expect(ConflictChoice.values.length, equals(3));
      expect(ConflictChoice.local.name, equals('local'));
      expect(ConflictChoice.remote.name, equals('remote'));
      expect(ConflictChoice.cancel.name, equals('cancel'));
    });
  });

  group('ConflictInfo', () {
    test('displayName returns entityName when provided', () {
      final info = ConflictInfo(
        entityType: 'Room',
        entityId: 'room_123',
        entityName: 'Living Room',
      );

      expect(info.displayName, equals('Living Room'));
    });

    test('displayName falls back to entityId', () {
      final info = ConflictInfo(
        entityType: 'Room',
        entityId: 'room_123',
      );

      expect(info.displayName, equals('room_123'));
    });
  });

  group('ConflictResolutionChoice', () {
    test('isLocal returns true for local choice', () {
      final choice = ConflictResolutionChoice(
        choice: ConflictChoice.local,
        conflict: ConflictInfo(entityType: 'Room', entityId: '1'),
        resolvedAt: DateTime.now(),
      );

      expect(choice.isLocal, isTrue);
      expect(choice.isRemote, isFalse);
      expect(choice.isCancelled, isFalse);
    });

    test('isRemote returns true for remote choice', () {
      final choice = ConflictResolutionChoice(
        choice: ConflictChoice.remote,
        conflict: ConflictInfo(entityType: 'Room', entityId: '1'),
        resolvedAt: DateTime.now(),
      );

      expect(choice.isLocal, isFalse);
      expect(choice.isRemote, isTrue);
      expect(choice.isCancelled, isFalse);
    });

    test('isCancelled returns true for cancel choice', () {
      final choice = ConflictResolutionChoice(
        choice: ConflictChoice.cancel,
        conflict: ConflictInfo(entityType: 'Room', entityId: '1'),
        resolvedAt: DateTime.now(),
      );

      expect(choice.isLocal, isFalse);
      expect(choice.isRemote, isFalse);
      expect(choice.isCancelled, isTrue);
    });
  });

  group('ConflictResolutionService', () {
    test('recordResolution adds to history', () {
      final service = ConflictResolutionService();
      
      final resolution = ConflictResolutionChoice(
        choice: ConflictChoice.local,
        conflict: ConflictInfo(entityType: 'Room', entityId: '1'),
        resolvedAt: DateTime.now(),
      );

      service.recordResolution(resolution);

      expect(service.resolvedConflicts.length, equals(1));
      expect(service.localWinsCount, equals(1));
      expect(service.remoteWinsCount, equals(0));
    });

    test('clearHistory clears all resolutions', () {
      final service = ConflictResolutionService();
      
      service.recordResolution(ConflictResolutionChoice(
        choice: ConflictChoice.local,
        conflict: ConflictInfo(entityType: 'Room', entityId: '1'),
        resolvedAt: DateTime.now(),
      ));

      service.clearHistory();

      expect(service.resolvedConflicts.length, equals(0));
    });

    test('localWinsCount and remoteWinsCount track correctly', () {
      final service = ConflictResolutionService();

      service.recordResolution(ConflictResolutionChoice(
        choice: ConflictChoice.local,
        conflict: ConflictInfo(entityType: 'Room', entityId: '1'),
        resolvedAt: DateTime.now(),
      ));

      service.recordResolution(ConflictResolutionChoice(
        choice: ConflictChoice.remote,
        conflict: ConflictInfo(entityType: 'Room', entityId: '2'),
        resolvedAt: DateTime.now(),
      ));

      service.recordResolution(ConflictResolutionChoice(
        choice: ConflictChoice.local,
        conflict: ConflictInfo(entityType: 'Room', entityId: '3'),
        resolvedAt: DateTime.now(),
      ));

      expect(service.localWinsCount, equals(2));
      expect(service.remoteWinsCount, equals(1));
    });
  });

  group('ConflictResolutionDialog Widget', () {
    testWidgets('displays conflict information', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await ConflictResolutionDialog.show(
                    context,
                    entityType: 'Room',
                    entityId: 'room_123',
                    entityName: 'Living Room',
                    localVersion: 1,
                    remoteVersion: 2,
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Sync Conflict'), findsOneWidget);
      expect(find.text('Local Version'), findsOneWidget);
      expect(find.text('Remote Version'), findsOneWidget);
      expect(find.text('Keep Local'), findsOneWidget);
      expect(find.text('Use Remote'), findsOneWidget);
    });

    testWidgets('Keep Local button returns local choice', (tester) async {
      ConflictResolutionChoice? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConflictResolutionDialog.show(
                    context,
                    entityType: 'Room',
                    entityId: 'room_123',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Keep Local'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.choice, equals(ConflictChoice.local));
    });

    testWidgets('Use Remote button returns remote choice', (tester) async {
      ConflictResolutionChoice? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConflictResolutionDialog.show(
                    context,
                    entityType: 'Room',
                    entityId: 'room_123',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use Remote'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.choice, equals(ConflictChoice.remote));
    });

    testWidgets('Cancel button returns cancel choice', (tester) async {
      ConflictResolutionChoice? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await ConflictResolutionDialog.show(
                    context,
                    entityType: 'Room',
                    entityId: 'room_123',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.choice, equals(ConflictChoice.cancel));
    });
  });
}
