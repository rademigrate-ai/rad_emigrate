class UserSession {
  final String? token;
  final bool authenticated;

  const UserSession({this.token, this.authenticated = false});
}
