class RoomModel {
  final String id;
  final String name;
  final int deviceCount;
  final String imageUrl;
  final String icon;
  final int color;

  RoomModel({
    required this.id,
    required this.name,
    required this.deviceCount,
    required this.imageUrl,
    String? icon,
    int? color,
  })  : icon = icon ?? 'images/sofa.png',
        color = color ?? 0xFF6C63FF;

  // Convert to JSON (useful for saving to backend later)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceCount': deviceCount,
      'imageUrl': imageUrl,
      'icon': icon,
      'color': color,
    };
  }

  // Create from JSON
  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceCount: json['deviceCount'] as int,
      imageUrl: json['imageUrl'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as int?,
    );
  }

  // Copy with method for updating
  RoomModel copyWith({
    String? id,
    String? name,
    int? deviceCount,
    String? imageUrl,
    String? icon,
    int? color,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceCount: deviceCount ?? this.deviceCount,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}
