import 'auth_service.dart';
import 'roles.dart';

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

  bool enterDevMode(String secretPin) {
    if (current == null) return false;
    if (secretPin == 'dev123') {
      // Hardcoded secret - change in production
      _developerMode = true;
      return true;
    }
    return false;
  }

  void exitDevMode() => _developerMode = false;
}
