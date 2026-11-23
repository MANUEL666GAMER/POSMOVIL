import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cash_close_repository.dart';

final activeShiftProvider = FutureProvider.autoDispose<CashClose?>((ref) async {
  final user = ref.watch(authStateProvider);
  if (user == null) return null;

  final repo = ref.read(cashCloseRepositoryProvider);
  return await repo.getActiveShift(user.id);
});