import 'auth_service.dart';

class Session {
  Session._();
  static final Session I = Session._();

  AuthUser? current;

  bool get isLoggedIn => current != null;

  void setUser(AuthUser u) => current = u;
  void logout() => current = null;
}
