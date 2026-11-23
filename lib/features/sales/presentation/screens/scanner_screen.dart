import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money.dart';
import '../../../products/presentation/providers/products_provider.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  final bool captureOnly;

  const ScannerScreen({super.key, this.captureOnly = false});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _torchOn = false;
  String? _detectedCode;
  Product? _matchedProduct;
  bool _notFound = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_detectedCode != null) return;
    final raw = capture.barcodes.firstOrNull?.rawValue?.trim();
    if (raw == null || raw.isEmpty) return;

    HapticFeedback.mediumImpact();

    if (widget.captureOnly) {
      Navigator.pop(context, raw);
      return;
    }

    final products = ref.read(productsListProvider).valueOrNull ?? [];
    final found = products.where((p) => p.barcode == raw).firstOrNull;

    setState(() {
      _detectedCode = raw;
      _matchedProduct = found;
      _notFound = found == null;
    });
  }

  void _resetScanner() {
    setState(() {
      _detectedCode = null;
      _matchedProduct = null;
      _notFound = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _matchedProduct != null
        ? const Color(0xFF66BB6A)
        : _notFound
            ? const Color(0xFFFFB74D)
            : Colors.white;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1110),
      body: Stack(
        children: [
          // Cámara
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetected,
          ),

          // Barra superior: Cerrar y Linterna
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Cerrar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _torchOn ? const Color(0xFFFFB74D) : Colors.black54,
                      foregroundColor: _torchOn ? const Color(0xFF2B1A00) : Colors.white,
                      minimumSize: const Size(0, 52),
                    ),
                    onPressed: () async {
                      await _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                    icon: Icon(_torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded),
                    label: const Text('Linterna', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),

          // Marco central de escaneo
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 280,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 4),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Apunta al código de barras',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'También funciona con escáner Bluetooth o USB',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // Tarjeta inferior cuando detecta un código
          if (_detectedCode != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor, width: 2),
                  ),
                  child: _matchedProduct != null
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _matchedProduct!.name,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                            ),
                            Text(
                              '${MoneyUtils.formatCents(_matchedProduct!.priceCents)} • Código $_detectedCode',
                              style: const TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 56),
                                    ),
                                    onPressed: _resetScanner,
                                    child: const Text('Escanear otro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF66BB6A),
                                      foregroundColor: const Color(0xFF0B1F0C),
                                      minimumSize: const Size(0, 56),
                                    ),
                                    onPressed: () => Navigator.pop(context, _matchedProduct),
                                    child: const Text('Agregar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Producto no encontrado',
                              style: TextStyle(color: Color(0xFFFFB74D), fontSize: 20, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Código $_detectedCode. ¿Quieres agregarlo al catálogo?',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 56),
                                    ),
                                    onPressed: _resetScanner,
                                    child: const Text('No, volver', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFB74D),
                                      foregroundColor: const Color(0xFF2B1A00),
                                      minimumSize: const Size(0, 56),
                                    ),
                                    onPressed: () => Navigator.pop(context, 'NEW:$_detectedCode'),
                                    child: const Text('Sí, agregarlo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}