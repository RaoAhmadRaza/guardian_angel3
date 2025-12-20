/// DEPRECATED: Use canonical PendingOp from persistence layer.
///
/// This file is deprecated and should NOT be used for new code.
/// Import from 'package:guardian_angel_fyp/persistence/models/pending_op.dart' instead.
///
/// Migration Guide:
/// 1. Replace: import '.../pending_op_hive.dart';
///    With:    import 'package:guardian_angel_fyp/persistence/models/pending_op.dart';
///
/// 2. Replace: PendingOp(opId: x, entityId: y, entityType: z, ...)
///    With:    PendingOp.forHomeAutomation(opId: x, entityId: y, entityType: z, ...)
///
/// 3. Use BoxRegistry.pendingOpsBox instead of kPendingOpsBoxName
///
/// TypeId 2 is DEPRECATED. Canonical TypeId is 11 (TypeIds.pendingOp).
@Deprecated('Use package:guardian_angel_fyp/persistence/models/pending_op.dart instead')
library;

// Re-export from canonical location
export 'package:guardian_angel_fyp/persistence/models/pending_op.dart';

/// DEPRECATED box name constant.
/// Use BoxRegistry.pendingOpsBox ('pending_ops_box') instead.
@Deprecated('Use BoxRegistry.pendingOpsBox instead')
const kPendingOpsBoxName = 'pending_ops_box';
