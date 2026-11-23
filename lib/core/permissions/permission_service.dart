enum AppRole {
  admin,
  cashier;

  static AppRole fromString(String value) {
    return AppRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppRole.cashier,
    );
  }
}

enum AppPermission {
  sell,
  viewProducts,
  manageProducts,
  viewCosts,
  manageInventory,
  ownCashClose,
  shareOwnCashClose,
  viewAllCashCloses,
  viewReports,
  exportReports,
  manageSettings,
  changeTheme,
}

class PermissionService {
  static bool can(AppRole role, AppPermission permission) {
    if (role == AppRole.admin) {
      // El administrador puede hacer todo
      return true;
    }

    // Permisos específicos para el cajero
    switch (permission) {
      case AppPermission.sell:
      case AppPermission.viewProducts:
      case AppPermission.ownCashClose:
      case AppPermission.shareOwnCashClose:
      case AppPermission.changeTheme:
        return true;
      case AppPermission.manageProducts:
      case AppPermission.viewCosts:
      case AppPermission.manageInventory: // El cajero solo puede consultar, no hacer entradas/ajustes
      case AppPermission.viewAllCashCloses:
      case AppPermission.viewReports:
      case AppPermission.exportReports:
      case AppPermission.manageSettings:
        return false;
    }
  }
}