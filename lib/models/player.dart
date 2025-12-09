class Player {
  final int id;
  final String name;
  final String phone;
  final String group;    // groupName
  final int? groupId;
  final int? age;
  final DateTime? joinDate;
  final String? photoUrl;
  final String? notes;

  Player({
    required this.id,
    required this.name,
    required this.phone,
    required this.group,
    this.groupId,
    this.age,
    this.joinDate,
    this.photoUrl,
    this.notes,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    // group detection
    String groupVal = '';
    if (json['group'] is String) {
      groupVal = json['group'] ?? '';
    } else if (json['groupName'] is String) {
      groupVal = json['groupName'] ?? '';
    } else if (json['group_name'] is String) {
      groupVal = json['group_name'] ?? '';
    } else if (json['group'] is Map) {
      groupVal = json['group']?['name'] ?? '';
    }

    // id
    int idVal = 0;
    if (json['id'] != null) {
      idVal = (json['id'] is int) ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0;
    }

    // groupId
    int? gid;
    final gvRaw = json['groupId'] ?? json['group_id'];
    if (gvRaw != null) {
      gid = (gvRaw is int) ? gvRaw : int.tryParse(gvRaw.toString());
    }

    // age
    int? ageVal;
    if (json['age'] != null) {
      ageVal = (json['age'] is int) ? json['age'] as int : int.tryParse(json['age'].toString());
    }

    // joinDate - expecting ISO 'YYYY-MM-DD' or full ISO
    DateTime? jd;
    final jdRaw = json['joinDate'] ?? json['join_date'];
    if (jdRaw != null) {
      try {
        jd = DateTime.parse(jdRaw.toString());
      } catch (e) {
        jd = null;
      }
    }

    // photoUrl and notes (accept both snake_case and camelCase)
    final String? photo = (json['photoUrl'] as String?) ??
        (json['photo_url'] as String?) ??
        (json['photo'] as String?);
    final String? notesVal = (json['notes'] as String?) ?? (json['note'] as String?);

    return Player(
      id: idVal,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      group: groupVal,
      groupId: gid,
      age: ageVal,
      joinDate: jd,
      photoUrl: photo,
      notes: notesVal,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'group': group,
    'groupId': groupId,
    'age': age,
    'joinDate': joinDate?.toIso8601String(),
    'photoUrl': photoUrl,
    'notes': notes,
  };
}
