class DeviceModel {
  final String id;
  final String roomId;
  final String type; // e.g. sensor, actuator
  final String status; // active/inactive
  final Map<String, dynamic> properties; // arbitrary key-values
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceModel({
    required this.id,
    required this.roomId,
    required this.type,
    required this.status,
    required this.properties,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        roomId: json['room_id'] as String,
        type: json['type'] as String,
        status: json['status'] as String? ?? 'active',
        properties: (json['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{},
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_id': roomId,
        'type': type,
        'status': status,
        'properties': properties,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      }..removeWhere((k, v) => v == null);
}