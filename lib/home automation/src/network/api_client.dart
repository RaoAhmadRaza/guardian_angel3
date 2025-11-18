import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown by the server client when an optimistic concurrency conflict occurs.
/// Contains the authoritative server entity so the client can resolve.
class ConflictException implements Exception {
  final Map<String, dynamic> serverEntity;
  final String message;
  ConflictException(this.serverEntity, {this.message = 'Version conflict'});

  @override
  String toString() => 'ConflictException($message)';
}

/// Minimal API client stub for syncing with a backend.
/// Replace implementations with real HTTP calls when a server is available.
class ApiClient {
  Duration get _latency => const Duration(milliseconds: 150);

  Future<void> createRoom(Map<String, dynamic> payload) async {
    await Future.delayed(_latency);
  }

  Future<void> updateRoom(String id, Map<String, dynamic> payload) async {
    await Future.delayed(_latency);
  }

  Future<void> deleteRoom(String id) async {
    await Future.delayed(_latency);
  }

  Future<void> createDevice(Map<String, dynamic> payload) async {
    await Future.delayed(_latency);
  }

  Future<void> updateDevice(String id, Map<String, dynamic> payload) async {
    await Future.delayed(_latency);
  }

  Future<void> deleteDevice(String id) async {
    await Future.delayed(_latency);
  }

  Future<void> toggleDevice(String id, bool isOn) async {
    await Future.delayed(_latency);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
