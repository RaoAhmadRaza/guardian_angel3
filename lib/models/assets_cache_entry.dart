class AssetsCacheEntry {
  final String key; // composite asset identifier
  final String checksum;
  final DateTime fetchedAt;
  final int sizeBytes;

  const AssetsCacheEntry({
    required this.key,
    required this.checksum,
    required this.fetchedAt,
    required this.sizeBytes,
  });

  factory AssetsCacheEntry.fromJson(Map<String, dynamic> json) => AssetsCacheEntry(
        key: json['key'] as String,
        checksum: json['checksum'] as String,
        fetchedAt: DateTime.parse(json['fetched_at'] as String).toUtc(),
        sizeBytes: (json['size_bytes'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'checksum': checksum,
        'fetched_at': fetchedAt.toUtc().toIso8601String(),
        'size_bytes': sizeBytes,
      };
}