class Group {
  final int id;
  final String name;
  final double currentFee; // ✅ New Field for displaying fee in list

  Group({
    required this.id,
    required this.name,
    this.currentFee = 0.0
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'],
      name: json['name'],
      // ✅ Handle null or int values safely
      currentFee: (json['currentFee'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'currentFee': currentFee,
  };
}