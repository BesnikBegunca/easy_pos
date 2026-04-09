# Easy POS Multi-Role Architecture Implementation
## Progress: 6/28 [█████░░░░░░░░░░░░░░░░░░░░░] 21%

### Phase 1: Roles & Auth (4 steps)
1. [x] lib/auth/roles.dart: Add superAdmin/developer enums + new perms (canAccessDevMode, canCreateAdmin, canEditOrders, isHighRole, roleHierarchy)
2. [x] lib/auth/session.dart: Add isDeveloperMode flag + enterDevMode(String secretPin) with hardcoded secret (e.g. 'dev123')
3. [x] lib/auth/guard.dart: New guards: requireDevMode(), requireSuperAdmin(), requireManagerOrHigher()
4. [x] lib/main.dart: Theme switching based on role (admin/super colorful)

### Phase 2: Developer Mode (4 steps)
5. [x] lib/screens/developer_mode_screen.dart: NEW - Full control screen (db tools, global pw reset, create admins, system logs)
6. [x] lib/screens/shell.dart: Add dev mode entry (hidden button/PIN after login if secret matches)
7. [ ] lib/auth/dao_users.dart: Add createSuperAdmin(), resetPwAnyUser(int userId), listAllUsersFullAccess()
8. [ ] lib/data/db.dart: Add dev repair queries (vacuum, integrity check)

### Phase 3: Logging/Audit System (5 steps)
9. [ ] lib/data/dao_logs.dart: NEW - AuditLogRow (action, userId, targetId, before/after JSON, timestamp, ip)
10. [ ] lib/screens/logs_screen.dart: NEW - Searchable/filterable logs table (by user/action/date)
11. [ ] Update all DAOs: Auto-log sensitive ops (settle/edit/create/delete/pw reset) via logAudit()
12. [ ] lib/auth/dao_users.dart: Log pw changes/creates
13. [ ] lib/data/dao_settlements.dart: Log settlements/reopens

### Phase 4: Enhanced Settlements & Corrections (4 steps)
14. [ ] lib/data/dao_settlements.dart: Add reopenSettlement(id, reason), requires manager+
15. [ ] lib/data/dao_orders.dart: Add editOrderPostSettlement(id, changes), log before/after
16. [ ] lib/screens/admin_dashboard.dart: Add reopen buttons (manager+), correction tools
17. [ ] lib/screens/settlement_screen.dart: Add correction flow with reason/approval

### Phase 5: UI & Role Distinction (5 steps)
18. [ ] lib/theme/app_theme.dart: Add adminTheme() colorful/no-dark + roleTheme(UserRole)
19. [ ] lib/screens/shell.dart: Switch theme/nav based on role (waiter simple, admin/super premium)
20. [ ] lib/screens/admin_dashboard.dart: SuperAdmin tabs (logs, dev entry), colorful layout
21. [ ] lib/screens/manage_users_screen.dart: SuperAdmin creates admins, role hierarchy guards
22. [ ] lib/theme/app_widgets.dart: Role-aware badges/cards

### Phase 6: Permissions Enforcement (3 steps)
23. [ ] Update manage_users_screen.dart: SuperAdmin only creates admins/supers
24. [ ] lib/screens/order_screen.dart: Manager can correct recent orders (pre-settlement)
25. [ ] All screens: Enforce guards (e.g. waiter no admin nav)

### Phase 7: Testing & Polish (3 steps)
26. [ ] Manual verification: Login each role, test perms/UI/logs/corrections/settle reopen
27. [ ] Add README updates for new roles/dev mode secret
28. [ ] attempt_completion: Production-ready POS delivered

**Legend:**
- [ ] Todo
- [x] Done
Update this file after each step completion.

