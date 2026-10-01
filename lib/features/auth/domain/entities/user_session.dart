class UserSession {
  final String? token;
  final String? userId;
  final String? email;
  final String? phone;
  final String? fullName;
  final bool authenticated;
  final bool profileComplete;

  const UserSession({
    this.token,
    this.userId,
    this.email,
    this.phone,
    this.fullName,
    this.authenticated = false,
    this.profileComplete = false,
  });

  UserSession copyWith({
    String? token,
    String? userId,
    String? email,
    String? phone,
    String? fullName,
    bool? authenticated,
    bool? profileComplete,
  }) {
    return UserSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      fullName: fullName ?? this.fullName,
      authenticated: authenticated ?? this.authenticated,
      profileComplete: profileComplete ?? this.profileComplete,
    );
  }

  bool get isAuthenticated => authenticated && token != null && token!.isNotEmpty;
}
