class DeviceModel {
  final String id;
  final String type; // light, lamp, fan
  final String name;
  final bool status;

  DeviceModel({
    required this.id,
    required this.type,
    required this.name,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'name': name,
        'status': status,
      };

  factory DeviceModel.fromMap(String id, Map<String, dynamic> map) {
    return DeviceModel(
      id: id,
      type: map['type'] ?? 'light',
      name: map['name'] ?? 'Unnamed Device',
      status: map['status'] ?? false,
    );
  }

  DeviceModel copyWith({
    String? id,
    String? type,
    String? name,
    bool? status,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      status: status ?? this.status,
    );
  }
}
