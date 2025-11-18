import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple online/offline signal for SyncService.
/// In production, connect this to a connectivity package or a health-check ping.
final networkStatusProvider = StateProvider<bool>((ref) => true);
