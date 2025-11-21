import 'dart:convert';

class RoomModel {
  final String id;
  final String name;
  final String? icon;
  final String? color;
  final List<String> deviceIds;
  final Map<String, dynamic>? meta;
  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RoomModel({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    required this.deviceIds,
    this.meta,
    this.schemaVersion = 1,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      deviceIds: (json['device_ids'] as List?)?.cast<String>() ?? const <String>[],
      meta: (json['meta'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'schema_version': schemaVersion,
      'name': name,
      'icon': icon,
      'color': color,
      'device_ids': deviceIds,
      'meta': meta,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  @override
  String toString() => jsonEncode(toJson());
}
