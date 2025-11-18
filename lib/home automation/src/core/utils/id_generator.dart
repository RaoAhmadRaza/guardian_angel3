import 'package:uuid/uuid.dart';

/// Global UUID generator instance.
final _uuid = const Uuid();

/// Generates a new unique identifier (v4 UUID).
String generateId() => _uuid.v4();
