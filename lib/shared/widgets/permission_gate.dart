import 'package:flutter/material.dart';
import '../../core/permissions/permission_service.dart';

class PermissionGate extends StatelessWidget {
  final AppRole currentRole;
  final AppPermission requiredPermission;
  final Widget child;
  final Widget? fallback;

  const PermissionGate({
    super.key,
    required this.currentRole,
    required this.requiredPermission,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = PermissionService.can(currentRole, requiredPermission);
    
    if (hasAccess) {
      return child;
    }
    
    return fallback ?? const SizedBox.shrink();
  }
}