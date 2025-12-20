/// Sync Providers
///
/// Riverpod providers for sync-related services.
/// Enables dependency injection of sync consumer into queue service.
library sync_providers;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sync_consumer.dart';
import 'default_sync_consumer.dart';
import 'conflict_resolver.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Provider for the API client.
///
/// This should be overridden in tests with a mock client.
final apiClientProvider = Provider<ApiClient>((ref) {
  // In production, this would be configured with real credentials
  // For now, throw an error indicating it needs to be overridden
  throw UnimplementedError(
    'apiClientProvider must be overridden with a configured ApiClient. '
    'Use ProviderScope with overrides to inject the real or mock client.',
  );
});

/// Provider for the auth service.
final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError(
    'authServiceProvider must be overridden with a configured AuthService.',
  );
});

/// Provider for the conflict resolver.
final conflictResolverProvider = Provider<ConflictResolver>((ref) {
  return DefaultConflictResolver();
});

/// Provider for the sync consumer.
///
/// Uses DefaultSyncConsumer with injected dependencies.
final syncConsumerProvider = Provider<SyncConsumer>((ref) {
  final api = ref.watch(apiClientProvider);
  final resolver = ref.watch(conflictResolverProvider);
  
  return DefaultSyncConsumer(
    api: api,
    conflictResolver: resolver,
  );
});

/// Provider for a no-op sync consumer (for offline/testing).
final noOpSyncConsumerProvider = Provider<SyncConsumer>((ref) {
  return NoOpSyncConsumer();
});

/// Provider for a failing sync consumer (for testing).
final failingSyncConsumerProvider = Provider.family<SyncConsumer, FailureType>((ref, failureType) {
  return FailingSyncConsumer(failureType: failureType);
});

/// Provider that returns the appropriate sync consumer based on connectivity.
///
/// Falls back to NoOpSyncConsumer when offline.
final adaptiveSyncConsumerProvider = Provider<SyncConsumer>((ref) {
  // Check if we have a valid API client configured
  try {
    final consumer = ref.watch(syncConsumerProvider);
    return consumer;
  } catch (_) {
    // Fall back to no-op if API client not configured
    return NoOpSyncConsumer();
  }
});
