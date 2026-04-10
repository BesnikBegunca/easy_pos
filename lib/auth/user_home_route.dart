import '../data/app_settings.dart';
import 'roles.dart';
import 'session.dart';

String userHomeRoute() {
  final user = Session.I.current;
  if (user == null) return '/login';
  if (Session.I.isDeveloperMode || canAccessAdminPanel(user.role)) {
    return '/shell';
  }
  return AppSettings.I.businessMode == 'market' ? '/market-pos' : '/shell';
}
