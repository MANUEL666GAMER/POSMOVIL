import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/money.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cash_close_repository.dart';
import '../providers/cash_close_provider.dart';
import '../../../../core/database/app_database.dart';


class CashCloseScreen extends ConsumerStatefulWidget {
  const CashCloseScreen({super.key});

  @override
  ConsumerState<CashCloseScreen> createState() => _CashCloseScreenState();
}

class _CashCloseScreenState extends ConsumerState<CashCloseScreen> {
  final _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleAction(bool isOpen, CashClose? activeShift) async {
    final amountCents = MoneyUtils.parseToCents(_amountController.text);
    final user = ref.read(authStateProvider);
    
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(cashCloseRepositoryProvider);
      
      if (isOpen) {
        await repo.openShift(userId: user.id, openingFloatCents: amountCents);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Turno abierto exitosamente')));
      } else {
        await repo.closeShift(activeShift: activeShift!, countedCashCents: amountCents);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Corte de caja realizado')));
      }
      
      _amountController.clear();
      ref.invalidate(activeShiftProvider); // Refresca la vista
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shiftAsync = ref.watch(activeShiftProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Caja y Turno')),
      body: shiftAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(activeShiftProvider)),
        data: (activeShift) {
          final isOpen = activeShift == null;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      isOpen ? Icons.lock_open : Icons.point_of_sale,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isOpen ? 'Abrir Turno' : 'Cerrar Turno',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    if (!isOpen) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Turno abierto desde:\n${DateFormat('dd/MM/yyyy HH:mm').format(activeShift.openedAt)}',
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'Fondo inicial: ${MoneyUtils.formatCents(activeShift.openingFloatCents)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 32),
                    AppTextField(
                      label: isOpen ? 'Fondo en caja (Morralla)' : 'Efectivo contado en caja',
                      controller: _amountController,
                      prefixIcon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 32),
                    AppButton(
                      label: isOpen ? 'Abrir Caja' : 'Realizar Corte',
                      isLoading: _isLoading,
                      onPressed: () => _handleAction(isOpen, activeShift),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}