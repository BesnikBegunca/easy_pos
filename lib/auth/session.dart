import 'auth_service.dart';

class Session {
  Session._();
  static final Session I = Session._();

  AuthUser? current;
  bool _developerMode = false;

  bool get isLoggedIn => current != null;
  bool get isDeveloperMode => _developerMode;

  void setUser(AuthUser u) => current = u;
  void logout() {
    current = null;
    _developerMode = false;
  }

  void enterDevMode() => _developerMode = true;
  void exitDevMode() => _developerMode = false;
}
