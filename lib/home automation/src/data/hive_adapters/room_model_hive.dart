import 'package:hive/hive.dart';

part 'room_model_hive.g.dart';

/// Box name for rooms
const kRoomsBoxName = 'rooms_box';

@HiveType(typeId: 0)
class RoomModelHive {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String iconId;

  @HiveField(3)
  final int color;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final DateTime updatedAt;

  @HiveField(6)
  final int version;

  // Optional local-only icon image path (stored in app documents dir)
  @HiveField(7)
  final String? iconPath;

  RoomModelHive({
    required this.id,
    required this.name,
    required this.iconId,
    required this.color,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.version = 0,
    this.iconPath,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  RoomModelHive copyWith({
    String? name,
    String? iconId,
    int? color,
    DateTime? updatedAt,
    int? version,
    String? iconPath,
  }) {
    return RoomModelHive(
      id: id,
      name: name ?? this.name,
      iconId: iconId ?? this.iconId,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      version: version ?? this.version,
      iconPath: iconPath ?? this.iconPath,
    );
  }
}
