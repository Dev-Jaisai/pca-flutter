// lib/models/group.dart
class Group {
  final int id;
  final String name;

  Group({required this.id, required this.name});

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: (json['id'] is int) ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? json['groupName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
  };
}
