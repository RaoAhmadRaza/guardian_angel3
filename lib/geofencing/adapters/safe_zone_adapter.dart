/// SafeZoneAdapter - Hive TypeAdapter for SafeZoneModel.
///
/// Provides serialization/deserialization for Hive storage.
library;

import 'package:hive/hive.dart';
import '../../persistence/type_ids.dart';
import '../models/safe_zone_model.dart';

/// Hive adapter for SafeZoneModel
class SafeZoneModelAdapter extends TypeAdapter<SafeZoneModel> {
  @override
  final int typeId = TypeIds.safeZone;

  @override
  SafeZoneModel read(BinaryReader reader) {
    final json = Map<String, dynamic>.from(reader.readMap());
    return SafeZoneModel.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, SafeZoneModel obj) {
    writer.writeMap(obj.toJson());
  }
}

/// Hive adapter for SafeZoneType enum
class SafeZoneTypeAdapter extends TypeAdapter<SafeZoneType> {
  @override
  final int typeId = TypeIds.safeZoneType;

  @override
  SafeZoneType read(BinaryReader reader) {
    final name = reader.readString();
    return SafeZoneType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SafeZoneType.other,
    );
  }

  @override
  void write(BinaryWriter writer, SafeZoneType obj) {
    writer.writeString(obj.name);
  }
}

/// Hive adapter for GeofenceEvent
class GeofenceEventAdapter extends TypeAdapter<GeofenceEvent> {
  @override
  final int typeId = TypeIds.geofenceEvent;

  @override
  GeofenceEvent read(BinaryReader reader) {
    final json = Map<String, dynamic>.from(reader.readMap());
    return GeofenceEvent.fromJson(json);
  }

  @override
  void write(BinaryWriter writer, GeofenceEvent obj) {
    writer.writeMap(obj.toJson());
  }
}

/// Hive adapter for GeofenceEventType enum
class GeofenceEventTypeAdapter extends TypeAdapter<GeofenceEventType> {
  @override
  final int typeId = TypeIds.geofenceEventType;

  @override
  GeofenceEventType read(BinaryReader reader) {
    final name = reader.readString();
    return GeofenceEventType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => GeofenceEventType.exit,
    );
  }

  @override
  void write(BinaryWriter writer, GeofenceEventType obj) {
    writer.writeString(obj.name);
  }
}

/// Register all geofencing adapters with Hive
void registerGeofencingAdapters() {
  if (!Hive.isAdapterRegistered(TypeIds.safeZone)) {
    Hive.registerAdapter(SafeZoneModelAdapter());
  }
  if (!Hive.isAdapterRegistered(TypeIds.safeZoneType)) {
    Hive.registerAdapter(SafeZoneTypeAdapter());
  }
  if (!Hive.isAdapterRegistered(TypeIds.geofenceEvent)) {
    Hive.registerAdapter(GeofenceEventAdapter());
  }
  if (!Hive.isAdapterRegistered(TypeIds.geofenceEventType)) {
    Hive.registerAdapter(GeofenceEventTypeAdapter());
  }
}
