class RoomModel {
  final String id;
  final String name;
  final String iconId; // e.g. 'sofa', 'bed'
  final int color; // ARGB color int
  final DateTime createdAt;
  final DateTime updatedAt;

  RoomModel({
    required this.id,
    required this.name,
    required this.iconId,
    required this.color,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  RoomModel copyWith({
    String? id,
    String? name,
    String? iconId,
    int? color,
    DateTime? updatedAt,
  }) => RoomModel(
        id: id ?? this.id,
        name: name ?? this.name,
        iconId: iconId ?? this.iconId,
        color: color ?? this.color,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'iconId': iconId,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static RoomModel fromMap(Map<String, dynamic> m) => RoomModel(
        id: m['id'] as String,
        name: m['name'] as String,
        iconId: m['iconId'] as String,
        color: m['color'] as int,
        createdAt: DateTime.parse(m['createdAt'] as String),
        updatedAt: DateTime.parse(m['updatedAt'] as String),
      );
}
