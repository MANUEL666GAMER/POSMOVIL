import 'package:flutter/material.dart';
import '../../core/permissions/permission_service.dart';

class UserAvatarTile extends StatelessWidget {
  final String name;
  final AppRole role;
  final bool isSelected;
  final VoidCallback onTap;

  const UserAvatarTile({
    super.key,
    required this.name,
    required this.role,
    this.isSelected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleName = role == AppRole.admin ? 'Administrador' : 'Cajero';
    
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      tileColor: isSelected 
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(roleName),
      trailing: isSelected 
          ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
          : null,
    );
  }
}