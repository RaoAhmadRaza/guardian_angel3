import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../data/local_hive_service.dart';
import '../../data/hive_adapters/room_model_hive.dart';
import '../../data/hive_adapters/device_model_hive.dart';
import '../../data/hive_adapters/pending_op_hive.dart';
import '../../data/repositories/room_repository_hive.dart';
import '../../data/repositories/device_repository_hive.dart';
import '../../core/config/app_config_provider.dart';

// Box providers
final roomsBoxProvider = Provider<Box<RoomModelHive>>((ref) => LocalHiveService.roomBox());
final devicesBoxProvider = Provider<Box<DeviceModelHive>>((ref) => LocalHiveService.deviceBox());
final pendingOpsBoxProvider = Provider<Box<PendingOp>>((ref) => LocalHiveService.pendingOpsBox());

// Hive-backed repository providers with pending op queue enabled
final hiveRoomRepositoryProvider = Provider<RoomRepositoryHive>((ref) {
	final box = ref.watch(roomsBoxProvider);
	final pending = ref.watch(pendingOpsBoxProvider);
	final cfg = ref.watch(appConfigProvider);
	final clientId = cfg.clientId ?? 'home-automation-app';
	return RoomRepositoryHive(box, pending, clientId);
});

final hiveDeviceRepositoryProvider = Provider<DeviceRepositoryHive>((ref) {
	final box = ref.watch(devicesBoxProvider);
	final pending = ref.watch(pendingOpsBoxProvider);
	final cfg = ref.watch(appConfigProvider);
	final clientId = cfg.clientId ?? 'home-automation-app';
	return DeviceRepositoryHive(box, pending, clientId);
});
