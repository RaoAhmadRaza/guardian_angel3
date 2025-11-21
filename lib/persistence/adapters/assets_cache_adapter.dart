import 'package:hive/hive.dart';
import '../../models/assets_cache_entry.dart';
import '../box_registry.dart';

class AssetsCacheEntryAdapter extends TypeAdapter<AssetsCacheEntry> {
  @override
  final int typeId = TypeIds.assetsCache;

  @override
  AssetsCacheEntry read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AssetsCacheEntry(
      key: fields[0] as String? ?? '',
      checksum: fields[1] as String? ?? '',
      fetchedAt: _parse(fields[2] as String?),
      sizeBytes: (fields[3] as int?) ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, AssetsCacheEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.key)
      ..writeByte(1)
      ..write(obj.checksum)
      ..writeByte(2)
      ..write(obj.fetchedAt.toUtc().toIso8601String())
      ..writeByte(3)
      ..write(obj.sizeBytes);
  }

  DateTime _parse(String? v) => v != null ? (DateTime.tryParse(v)?.toUtc() ?? DateTime.now().toUtc()) : DateTime.now().toUtc();
}