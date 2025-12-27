class Player {
  final int id;
  final String name;
  final String phone;
  final String group;
  final int? groupId;
  final int? age;
  final DateTime? joinDate;
  final String? photoUrl;
  final String? notes;

  // ✅ BILLING FIELDS
  final int? billingDay;
  final int? paymentCycleMonths;

  // 🔥 NEW FIELDS: Holiday/Left Status & Wallet
  final bool isActive;
  final double? creditBalance; // 🔥 NEW: Wallet Balance

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
    this.billingDay,
    this.paymentCycleMonths,
    this.isActive = true,
    this.creditBalance = 0.0, // 🔥 Default 0.0
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    // 1. Group Detection
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

    // 2. ID Parsing
    int idVal = 0;
    if (json['id'] != null) {
      if (json['id'] is int) {
        idVal = json['id'];
      } else if (json['id'] is String) {
        idVal = int.tryParse(json['id']) ?? 0;
      }
    }

    // 3. Group ID
    int? gid;
    final gvRaw = json['groupId'] ?? json['group_id'];
    if (gvRaw != null) {
      gid = (gvRaw is int) ? gvRaw : int.tryParse(gvRaw.toString());
    }

    // 4. Age
    int? ageVal;
    if (json['age'] != null) {
      ageVal = (json['age'] is int) ? json['age'] as int : int.tryParse(json['age'].toString());
    }

    // 5. Join Date
    DateTime? jd;
    final jdRaw = json['joinDate'] ?? json['join_date'];
    if (jdRaw != null) {
      try {
        jd = DateTime.parse(jdRaw.toString());
      } catch (e) {
        jd = null;
      }
    }

    // 6. Photo & Notes
    final String? photo = (json['photoUrl'] as String?) ??
        (json['photo_url'] as String?) ??
        (json['photo'] as String?);
    final String? notesVal = (json['notes'] as String?) ?? (json['note'] as String?);

    // 7. Billing Day Logic
    var bDayRaw = json['billingDay'] ?? json['billing_day'];
    int? bDay;
    if (bDayRaw != null) {
      bDay = (bDayRaw is int) ? bDayRaw : int.tryParse(bDayRaw.toString());
    }

    // 8. Payment Cycle Logic
    var pCycleRaw = json['paymentCycleMonths'] ?? json['payment_cycle_months'];
    int? pCycle;
    if (pCycleRaw != null) {
      pCycle = (pCycleRaw is int) ? pCycleRaw : int.tryParse(pCycleRaw.toString());
    }

    // 9. Is Active Logic
    bool activeVal = true;
    if (json['isActive'] != null) {
      activeVal = json['isActive'] as bool;
    } else if (json['is_active'] != null) {
      if (json['is_active'] is int) {
        activeVal = json['is_active'] == 1;
      } else {
        activeVal = json['is_active'];
      }
    }

    // 🔥 10. Credit Balance Parsing (NEW)
    double creditVal = 0.0;
    if (json['creditBalance'] != null) {
      creditVal = (json['creditBalance'] as num).toDouble();
    } else if (json['credit_balance'] != null) {
      creditVal = (json['credit_balance'] as num).toDouble();
    }

    return Player(
      id: idVal,
      name: json['name'] ?? 'Unknown',
      phone: json['phone'] ?? '',
      group: groupVal,
      groupId: gid,
      age: ageVal,
      joinDate: jd,
      photoUrl: photo,
      notes: notesVal,
      billingDay: bDay,
      paymentCycleMonths: pCycle,
      isActive: activeVal,
      creditBalance: creditVal, // 🔥 Mapped Here
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
    'billingDay': billingDay,
    'paymentCycleMonths': paymentCycleMonths,
    'isActive': isActive,
    'creditBalance': creditBalance, // 🔥 Added Here
  };
}