// ── Emergency Contact ─────────────────────────────────────────────────────────

class EmergencyContact {
  final String name;
  final String phone;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.relation = '',
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: (json['name'] as String? ?? '').trim(),
      phone: (json['phone'] as String? ?? '').trim(),
      relation: (json['relation'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'relation': relation,
      };

  EmergencyContact copyWith({String? name, String? phone, String? relation}) {
    return EmergencyContact(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
    );
  }

  @override
  String toString() => 'EmergencyContact(name: $name, phone: $phone, relation: $relation)';
}

// ── User Profile ──────────────────────────────────────────────────────────────

class UserProfile {
  final String uid;
  final String name;
  final int age;
  final String gender;
  final String bloodGroup;
  final String phoneNumber;
  final List<EmergencyContact> emergencyContacts;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    required this.bloodGroup,
    required this.phoneNumber,
    this.emergencyContacts = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final contacts = (json['emergencyContacts'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(EmergencyContact.fromJson)
        .toList();

    return UserProfile(
      uid: json['uid'] as String? ?? '',
      name: json['name'] as String? ?? '',
      age: (json['age'] as num? ?? 0).toInt(),
      gender: json['gender'] as String? ?? '',
      bloodGroup: json['bloodGroup'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      emergencyContacts: contacts,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'age': age,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'phoneNumber': phoneNumber,
        'emergencyContacts': emergencyContacts.map((e) => e.toJson()).toList(),
      };

  UserProfile copyWith({
    String? name,
    int? age,
    String? gender,
    String? bloodGroup,
    String? phoneNumber,
    List<EmergencyContact>? emergencyContacts,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  static const List<String> genderOptions = [
    'Male', 'Female', 'Other', 'Prefer not to say'
  ];

  static const List<String> bloodGroupOptions = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'Unknown'
  ];

  @override
  String toString() =>
      'UserProfile(uid: $uid, name: $name, age: $age, gender: $gender, bloodGroup: $bloodGroup)';
}
