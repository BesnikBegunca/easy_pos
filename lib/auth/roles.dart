enum UserRole { developer, superAdmin, admin, manager, waiter }

UserRole roleFromString(String v) {
  switch (v) {
    case 'developer':
      return UserRole.developer;
    case 'superAdmin':
      return UserRole.superAdmin;
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
    case UserRole.developer:
      return 'developer';
    case UserRole.superAdmin:
      return 'superAdmin';
    case UserRole.admin:
      return 'admin';
    case UserRole.manager:
      return 'manager';
    case UserRole.waiter:
      return 'waiter';
  }
}

bool canViewReports(UserRole r) =>
    r == UserRole.developer ||
    r == UserRole.superAdmin ||
    r == UserRole.admin ||
    r == UserRole.manager;
bool canAccessAdminPanel(UserRole r) =>
    r == UserRole.developer ||
    r == UserRole.superAdmin ||
    r == UserRole.admin ||
    r == UserRole.manager;
bool canManageUsers(UserRole r) => canAccessAdminPanel(r);
bool canManageProducts(UserRole r) => canAccessAdminPanel(r);
bool canSettleWorkers(UserRole r) => canAccessAdminPanel(r);
bool canAccessSystemSettings(UserRole r) =>
    r == UserRole.developer || r == UserRole.superAdmin || r == UserRole.admin;
bool canAccessCoreConfiguration(UserRole r) => canAccessSystemSettings(r);

bool canAccessDevMode(UserRole r) => r == UserRole.developer;
bool canCreateAdmin(UserRole r) =>
    r == UserRole.developer || r == UserRole.superAdmin;
bool canEditOrders(UserRole r) =>
    r == UserRole.developer ||
    r == UserRole.superAdmin ||
    r == UserRole.admin ||
    r == UserRole.manager;
bool isHighRole(UserRole r) =>
    r == UserRole.developer || r == UserRole.superAdmin || r == UserRole.admin;

int roleLevel(UserRole r) {
  return switch (r) {
    UserRole.developer => 5,
    UserRole.superAdmin => 4,
    UserRole.admin => 3,
    UserRole.manager => 2,
    UserRole.waiter => 1,
  };
}
