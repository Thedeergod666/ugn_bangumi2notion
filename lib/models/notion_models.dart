class NotionProperty {
  final String name;
  final String type;

  NotionProperty({required this.name, required this.type});

  Map<String, String> toJson() {
    return {
      'name': name,
      'type': type,
    };
  }

  factory NotionProperty.fromJson(Map<String, dynamic> json) {
    return NotionProperty(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotionProperty &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          type == other.type;

  @override
  int get hashCode => name.hashCode ^ type.hashCode;
}
