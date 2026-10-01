/// Production user profile domain model (immutable, serializable).
class UserProfile {
  const UserProfile({
    required this.id,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.nationality,
    this.avatar,
    this.createdAt,
  });

  final String id;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? nationality;
  final String? avatar;
  final DateTime? createdAt;

  String get fullName {
    final parts = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty);
    return parts.isEmpty ? '' : parts.join(' ');
  }

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? nationality,
    String? avatar,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      nationality: nationality ?? this.nationality,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'nationality': nationality,
        'avatar': avatar,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      nationality: json['nationality'] as String?,
      avatar: json['avatar'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          firstName == other.firstName &&
          lastName == other.lastName &&
          email == other.email &&
          phone == other.phone &&
          nationality == other.nationality &&
          avatar == other.avatar &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        firstName,
        lastName,
        email,
        phone,
        nationality,
        avatar,
        createdAt,
      );
}
