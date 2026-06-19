import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';

import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/localization_helper.dart';

class AdScreen extends StatefulWidget {
  const AdScreen({super.key});

  @override
  State<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends State<AdScreen> {
  static const Color _bg = Color(0xFFF5EFE8);
  static const Color _paper = Color(0xFFF6EFE7);
  static const Color _darkBrown = Color(0xFF2B160C);
  static const Color _muted = Color(0xFF9B8A78);

  final ScreenshotController _screenshotController = ScreenshotController();

  List<_AdBranchOption> _branchOptions = const <_AdBranchOption>[];
  _AdBranchOption? _selectedBranch;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final selection = await StylistBranchSelectionStore.load();
      final response = await ApiService().getSalonListApi();
      final rawSalons =
          response['data'] is List ? response['data'] as List : const [];
      final options = _extractBranchOptions(rawSalons);
      final selected = options.cast<_AdBranchOption?>().firstWhere(
            (option) => option?.branchId == selection.branchId,
            orElse: () => options.isEmpty ? null : options.first,
          );
      if (!mounted) return;
      setState(() {
        _branchOptions = options;
        _selectedBranch = selected;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _branchOptions = const <_AdBranchOption>[];
        _selectedBranch = null;
      });
    }
  }

  List<_AdBranchOption> _extractBranchOptions(List<dynamic> rawSalons) {
    final options = <_AdBranchOption>[];
    for (final salonEntry in rawSalons) {
      if (salonEntry is! Map) continue;
      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _asInt(salon['id']);
      if (salonId == null) continue;
      final salonName = _cleanText(salon['name']);
      final branches = (salon['branches'] as List?) ?? const [];
      for (final branchEntry in branches) {
        if (branchEntry is! Map) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _asInt(branch['id']);
        if (branchId == null) continue;
        options.add(
          _AdBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
            address: _addressSummary(branch['address']),
          ),
        );
      }
    }
    return options;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}');
  }

  String _cleanText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _addressSummary(dynamic rawAddress) {
    if (rawAddress is! Map) return '';
    final address = Map<String, dynamic>.from(rawAddress);
    final parts = <String>[];
    for (final key in ['line1', 'line2', 'city', 'state']) {
      final value = _cleanText(address[key]);
      if (value.isNotEmpty && !parts.contains(value)) parts.add(value);
    }
    return parts.take(2).join(', ');
  }

  Future<void> _switchBranch(_AdBranchOption branch) async {
    setState(() => _selectedBranch = branch);
    await StylistBranchSelectionStore.save(
      salonId: branch.salonId,
      branchId: branch.branchId,
      salonName: branch.salonName,
      branchName: branch.branchName,
    );
  }

  Widget _buildBranchSelector() {
    final selected = _selectedBranch;
    if (selected == null) return const SizedBox.shrink();
    return OwnerBranchHeaderSelector<_AdBranchOption>(
      label: selected.displayLabel,
      options: _branchOptions
          .map(
            (option) => OwnerBranchHeaderSelectorOption<_AdBranchOption>(
              value: option,
              label: option.displayLabel,
              subtitle: option.address,
            ),
          )
          .toList(),
      selectedValue: selected,
      placeholder: translateText('Select Branch'),
      isInteractive: _branchOptions.length > 1,
      onSelected: _switchBranch,
    );
  }

  Future<Uint8List> _buildPdfBytes() async {
    final imageBytes = await _screenshotController.capture(
      pixelRatio: 3,
      delay: const Duration(milliseconds: 300),
    );

    if (imageBytes == null) {
      throw Exception('Unable to capture advertisement.');
    }

    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Center(
            child: pw.Image(
              image,
              fit: pw.BoxFit.contain,
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  Future<void> _sharePdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      final bytes = await _buildPdfBytes();

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'beauty_salon_ad.pdf',
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_isExporting) return;

    setState(() => _isExporting = true);

    try {
      final bytes = await _buildPdfBytes();

      await Printing.layoutPdf(
        name: 'beauty_salon_ad.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardSize = screenWidth >= 520 ? 450.0 : screenWidth - 36;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Advertisement',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 28, 18, 32),
          child: Column(
            children: [
              if (_selectedBranch != null) ...[
                _buildBranchSelector(),
                const SizedBox(height: 20),
              ],
              const Text(
                'H O V E R   P H O T O S   T O   R E P L A C E   -   E D I T   T E X T   I N   P A N E L',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 7,
                  letterSpacing: 3,
                  color: Color(0xFFC8B8A8),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Screenshot(
                  controller: _screenshotController,
                  child: SizedBox(
                    width: cardSize,
                    height: cardSize,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Container(
                        width: 450,
                        height: 450,
                        decoration: BoxDecoration(
                          color: _paper,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 28,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Positioned(
                              left: 24,
                              top: 28,
                              child: _LeafDecoration(
                                width: 74,
                                height: 96,
                                opacity: 0.62,
                                rotate: -0.22,
                              ),
                            ),
                            const Positioned(
                              right: -6,
                              bottom: -8,
                              child: _LeafDecoration(
                                width: 70,
                                height: 92,
                                opacity: 0.72,
                                rotate: 0.55,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(26, 30, 16, 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    flex: 48,
                                    child: _AdTextPanel(),
                                  ),
                                  const SizedBox(width: 22),
                                  Expanded(
                                    flex: 52,
                                    child: Column(
                                      children: const [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _ImageTile(
                                                height: 102,
                                                imageUrl:
                                                    'https://images.unsplash.com/photo-1560066984-138dadb4c035?q=80&w=600&auto=format&fit=crop',
                                                grayscale: true,
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: _ImageTile(
                                                height: 102,
                                                imageUrl:
                                                    'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?q=80&w=600&auto=format&fit=crop',
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _ImageTile(
                                                height: 102,
                                                imageUrl:
                                                    'https://images.unsplash.com/photo-1604654894610-df63bc536371?q=80&w=600&auto=format&fit=crop',
                                              ),
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: _ImageTile(
                                                height: 102,
                                                imageUrl:
                                                    'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?q=80&w=600&auto=format&fit=crop',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Positioned(
                              left: 26,
                              bottom: 18,
                              child: Text(
                                '123 Anywhere St., Any City',
                                style: TextStyle(
                                  fontSize: 6.5,
                                  color: _muted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 36,
                    child: OutlinedButton(
                      onPressed: _isExporting ? null : _sharePdf,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD6A13B)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        backgroundColor: Colors.transparent,
                        foregroundColor: _darkBrown,
                        padding: EdgeInsets.zero,
                      ),
                      child: _isExporting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.5),
                            )
                          : const Text(
                              'S H A R E',
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 154,
                    height: 36,
                    child: ElevatedButton(
                      onPressed: _isExporting ? null : _downloadPdf,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _darkBrown,
                        foregroundColor: const Color(0xFFD4A23E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isExporting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.5),
                            )
                          : const Text(
                              'D O W N L O A D   P D F',
                              style: TextStyle(
                                fontSize: 8,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdTextPanel extends StatelessWidget {
  const _AdTextPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'W E L C O M E   T O',
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 4,
              color: Color(0xFFB59B83),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Beauty\nSalon',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 31,
              height: 0.95,
              color: Color(0xFF3A2418),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
          SizedBox(
            width: 32,
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFF8B6F52),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Pamper yourself in our beauty salon. We use the\nfinest products for all your beauty needs.',
            style: TextStyle(
              fontSize: 7.5,
              height: 1.65,
              color: Color(0xFF716151),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 20),
          Text(
            'O U R   S E R V I C E S',
            style: TextStyle(
              fontSize: 8,
              letterSpacing: 4,
              color: Color(0xFF8B6F52),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          _ServiceLine('Hair Treatment'),
          _ServiceLine('Skin Care'),
          _ServiceLine('Manicure & Pedicure'),
          _ServiceLine('Body Massage'),
          SizedBox(height: 20),
          _BookButton(),
          SizedBox(height: 10),
          Text(
            '+91 98765 43210',
            style: TextStyle(
              fontSize: 7,
              color: Color(0xFF9B8A78),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdBranchOption {
  const _AdBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get displayLabel {
    if (branchName.trim().isNotEmpty) return branchName.trim();
    if (salonName.trim().isNotEmpty) return salonName.trim();
    return 'Branch #$branchId';
  }
}

class _ServiceLine extends StatelessWidget {
  const _ServiceLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF8B6F52),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 7.5,
              color: Color(0xFF5D4D3F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookButton extends StatelessWidget {
  const _BookButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 98,
      height: 27,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(0xFF8B6F52),
        borderRadius: BorderRadius.circular(2),
      ),
      child: const Text(
        'B O O K   N O W',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          letterSpacing: 2.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.height,
    required this.imageUrl,
    this.grayscale = false,
  });

  final double height;
  final String imageUrl;
  final bool grayscale;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        color: const Color(0xFFE3D8CE),
        child: const Icon(
          Icons.image_outlined,
          color: Color(0xFF8B6F52),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: grayscale
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0.2126,
                0.7152,
                0.0722,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: image,
            )
          : image,
    );
  }
}

class _LeafDecoration extends StatelessWidget {
  const _LeafDecoration({
    required this.width,
    required this.height,
    required this.opacity,
    required this.rotate,
  });

  final double width;
  final double height;
  final double opacity;
  final double rotate;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate,
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: Size(width, height),
          painter: _LeafPainter(),
        ),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = const Color(0xFFC8B8A8)
      ..style = PaintingStyle.fill;

    final line = Paint()
      ..color = const Color(0xFFA99582)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(size.width * 0.5, 0)
      ..cubicTo(
        size.width * 1.05,
        size.height * 0.18,
        size.width * 0.95,
        size.height * 0.82,
        size.width * 0.5,
        size.height,
      )
      ..cubicTo(
        size.width * 0.05,
        size.height * 0.82,
        -size.width * 0.05,
        size.height * 0.18,
        size.width * 0.5,
        0,
      )
      ..close();

    canvas.drawPath(path, fill);

    canvas.drawLine(
      Offset(size.width * 0.5, size.height * 0.05),
      Offset(size.width * 0.5, size.height * 0.95),
      line,
    );

    for (var i = 1; i <= 4; i++) {
      final y = size.height * (i / 5);

      canvas.drawLine(
        Offset(size.width * 0.5, y),
        Offset(size.width * 0.78, y - 18),
        line,
      );

      canvas.drawLine(
        Offset(size.width * 0.5, y),
        Offset(size.width * 0.22, y + 18),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
