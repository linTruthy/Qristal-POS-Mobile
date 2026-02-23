enum UserRole {
  OWNER,
  MANAGER,
  CASHIER,
  WAITER,
  KITCHEN
}

extension UserRoleExtension on String {
  UserRole toUserRole() {
    return UserRole.values.firstWhere(
      (e) => e.toString().split('.').last == this,
      orElse: () => UserRole.WAITER,
    );
  }
}