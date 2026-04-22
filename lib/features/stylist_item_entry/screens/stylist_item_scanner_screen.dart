import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../stylist_item_entry_theme.dart';
import '../stylist_used_item.dart';
import 'stylist_used_item_editor_screen.dart';

class StylistItemScannerScreen extends StatefulWidget {
  const StylistItemScannerScreen({super.key});

  @override
  State<StylistItemScannerScreen> createState() =>
      _StylistItemScannerScreenState();
}

class _StylistItemScannerScreenState extends State<StylistItemScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isHandlingDetection = false;
  bool _isTorchOn = false;

  Future<void> _openScannedDetails(String code) async {
    final savedItem = await Navigator.of(context).push<StylistUsedItem>(
      MaterialPageRoute(
        builder: (_) => StylistUsedItemEditorScreen(
          title: 'Scanned Product Details',
          subtitle:
              'Review the scanned product information before saving it locally.',
          submitLabel: 'Use This Item',
          sourceLabel: 'Camera scan',
          initialItem: StylistUsedItem.fromScanCode(code),
          codeReadOnly: true,
        ),
      ),
    );

    if (!mounted) return;

    if (savedItem != null) {
      Navigator.of(context).pop(savedItem);
      return;
    }

    setState(() => _isHandlingDetection = false);
    await _controller.start();
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isHandlingDetection) return;

    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );

    if (rawValue.isEmpty) return;

    setState(() => _isHandlingDetection = true);
    await _controller.stop();
    await _openScannedDetails(rawValue);
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    setState(() => _isTorchOn = !_isTorchOn);
  }

  Future<void> _openManualEntry() async {
    final navigator = Navigator.of(context);
    final item = await navigator.push<StylistUsedItem>(
      MaterialPageRoute(
        builder: (_) => const StylistUsedItemEditorScreen(
          title: 'Enter Item Details',
          subtitle: 'Add beauty product usage manually for this appointment.',
          submitLabel: 'Save Item',
          sourceLabel: 'Manual entry',
        ),
      ),
    );
    if (!mounted || item == null) return;
    navigator.pop(item);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _handleDetection,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _ScannerActionButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      _ScannerActionButton(
                        icon: _isTorchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        onTap: _toggleTorch,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Container(
                              width: double.infinity,
                              height: 2,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              color: stylistItemAccent.withValues(alpha: 0.85),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            child: _ScanCorner(alignment: Alignment.topLeft),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: _ScanCorner(alignment: Alignment.topRight),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: _ScanCorner(alignment: Alignment.bottomLeft),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _ScanCorner(
                              alignment: Alignment.bottomRight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.58),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan barcode or QR code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Place the product code inside the frame. After scanning, the product details screen opens for review.',
                        style: TextStyle(
                          color: Color(0xFFE7E5E4),
                          fontSize: 14,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _openManualEntry,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Enter details instead',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerActionButton extends StatelessWidget {
  const _ScannerActionButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _ScanCorner extends StatelessWidget {
  const _ScanCorner({
    required this.alignment,
  });

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: stylistItemAccent, width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: stylistItemAccent, width: 4)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: stylistItemAccent, width: 4)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: stylistItemAccent, width: 4)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: isTop && isLeft ? const Radius.circular(24) : Radius.zero,
          topRight: isTop && !isLeft ? const Radius.circular(24) : Radius.zero,
          bottomLeft:
              !isTop && isLeft ? const Radius.circular(24) : Radius.zero,
          bottomRight:
              !isTop && !isLeft ? const Radius.circular(24) : Radius.zero,
        ),
      ),
    );
  }
}
