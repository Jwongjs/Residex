

class MoveInPhoto {
  final String areaId;
  final String areaName;
  final String filePath;
  final DateTime timestamp;

  MoveInPhoto({
    required this.areaId,
    required this.areaName,
    required this.filePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'areaId': areaId,
    'areaName': areaName,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MoveInPhoto.fromJson(Map<String, dynamic> json) => MoveInPhoto(
    areaId: json['areaId'] as String,
    areaName: json['areaName'] as String,
    filePath: json['filePath'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}