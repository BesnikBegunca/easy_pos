enum UserRole { admin, manager, waiter }

UserRole roleFromString(String v) {
  switch (v) {
    case 'admin':
      return UserRole.admin;
    case 'manager':
      return UserRole.manager;
    default:
      return UserRole.waiter;
  }
}

String roleToString(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'admin';
    case UserRole.manager:
      return 'manager';
    case UserRole.waiter:
      return 'waiter';
  }
}

bool canViewReports(UserRole r) => r == UserRole.admin || r == UserRole.manager;
bool canManageUsers(UserRole r) => r == UserRole.admin;
