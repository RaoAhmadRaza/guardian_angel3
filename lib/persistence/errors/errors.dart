/// Persistence Error Handling
///
/// Exports all error handling utilities for the Hive persistence layer.
///
/// Usage:
/// ```dart
/// import 'package:guardian_angel_fyp/persistence/errors/errors.dart';
///
/// try {
///   await box.put(key, value);
/// } catch (e, st) {
///   final error = HiveErrorHandler.categorize(e, st, boxName: 'my_box');
///   HiveErrorHandler.record(error);
///   // Show error.userMessage to user
/// }
/// ```
library;

export 'hive_error_handler.dart';
export 'safe_box_ops.dart';
