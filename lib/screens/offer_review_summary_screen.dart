import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../utils/price_formatter.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

class OfferReviewSummaryScreen extends StatefulWidget {
  const OfferReviewSummaryScreen({
    super.key,
    required this.isPackage,
    required this.isEdit,
    required this.title,
    required this.pricingMode,
    required this.discountType,
    required this.amountOff,
    required this.maxDiscount,
    required this.originalPrice,
    required this.discountedPrice,
    required this.terms,
    required this.durationValue,
    required this.durationUnit,
    required this.validFrom,
    required this.validTill,
    required this.selectedServices,
    required this.onSubmit,
    required this.isSubmitting,
  });

  final bool isPackage;
  final bool isEdit;
  final String title;
  final String pricingMode;
  final String discountType;
  final String amountOff;
  final String maxDiscount;
  final String originalPrice;
  final String discountedPrice;
  final String terms;
  final String durationValue;
  final String durationUnit;
  final String validFrom;
  final String validTill;
  final List<Map<String, dynamic>> selectedServices;
  final Future<void> Function() onSubmit;
  final bool isSubmitting;

  @override
  State<OfferReviewSummaryScreen> createState() =>
      _OfferReviewSummaryScreenState();
}

class _OfferReviewSummaryScreenState extends State<OfferReviewSummaryScreen> {
  bool _localSubmitting = false;

  static const Color _gold = Color(0xFF8B6500);
  static const Color _ink = Color(0xFF1F1B18);
  static const Color _muted = Color(0xFF6F665E);
  static const Color _border = Color(0xFFE8DED6);
  static const Color _surface = Color(0xFFFBFAF8);
  static const Color _fieldFill = Color(0xFFF7F4F3);
  static const Color _softGold = Color(0xFFF5EAD2);

  String get _discountLabel {
    if (widget.pricingMode == 'Fixed') return 'Amount Off';
    if (widget.discountType == 'Percent') return 'Percentage Off';
    return 'Amount Off';
  }

  String get _discountValue {
    if (widget.pricingMode == 'Fixed') return _rupeeInputLabel(widget.amountOff);
    if (widget.discountType == 'Percent') return '${widget.amountOff}%';
    return _rupeeInputLabel(widget.amountOff);
  }

  String _rupeeInputLabel(String value) {
    final parsed = num.tryParse(value.trim());
    return parsed == null ? (value.trim().isEmpty ? '-' : value) : formatRupeeAmount(parsed);
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _gold),
          const SizedBox(width: 8),
          Text(
            translateText(title),
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    final display = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              translateText(label),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.w900 : FontWeight.w800,
                color: highlight ? _gold : _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceBox(String label, String value, {bool primary = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: primary ? _softGold : _fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primary ? _gold.withValues(alpha: .25) : _border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              translateText(label),
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _rupeeInputLabel(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: primary ? _gold : _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _serviceCard(Map<String, dynamic> service) {
    final name = (service['name'] ?? '').toString();
    final price = service['price'] ?? 0;
    final qty = (service['qty'] ?? 0).toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.spa_outlined, color: _gold, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name.isEmpty ? translateText('Service') : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Qty: $qty  ${formatMinorAmount(price)}',
            style: const TextStyle(
              color: _gold,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.isPackage
        ? translateText('Package Summary')
        : translateText('Deal Summary');

    final submitLabel = widget.isEdit
        ? widget.isPackage
            ? translateText('Update Package')
            : translateText('Update Deal')
        : widget.isPackage
            ? translateText('Create Package')
            : translateText('Create Deal');
    final submitting = widget.isSubmitting || _localSubmitting;

    return Scaffold(
      backgroundColor: _surface,
      appBar: buildProfileSubpageAppBar(title: pageTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: _softGold,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.isPackage
                            ? Icons.inventory_2_rounded
                            : Icons.local_offer_rounded,
                        color: _gold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translateText('Review Summary'),
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            translateText('Please verify details before submitting.'),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              _sectionTitle(
                widget.isPackage ? 'Package Information' : 'Deal Information',
                Icons.info_outline_rounded,
              ),
              _infoCard(
                children: [
                  _row(widget.isPackage ? 'Package Title' : 'Deal Title', widget.title),
                  _row('Pricing Option', widget.pricingMode),
                  if (widget.pricingMode == 'Discount')
                    _row('Discount Type', widget.discountType),
                  _row(_discountLabel, _discountValue, highlight: true),
                  if (widget.pricingMode == 'Discount' && widget.discountType == 'Percent')
                    _row('Max Discount', _rupeeInputLabel(widget.maxDiscount)),
                  _row('Terms', widget.terms),
                  if (widget.isPackage)
                    _row('Duration', '${widget.durationValue} ${widget.durationUnit}')
                  else ...[
                    _row('Start Date', widget.validFrom),
                    _row('End Date', widget.validTill),
                  ],
                ],
              ),

              const SizedBox(height: 18),
              _sectionTitle('Price Summary', Icons.payments_outlined),
              Row(
                children: [
                  _priceBox('Original Price', widget.originalPrice),
                  const SizedBox(width: 12),
                  _priceBox('Discounted Price', widget.discountedPrice, primary: true),
                ],
              ),

              const SizedBox(height: 18),
              _sectionTitle('Selected Services', Icons.spa_outlined),
              if (widget.selectedServices.isEmpty)
                _infoCard(
                  children: [
                    Text(
                      translateText('No services selected'),
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                )
              else
                _infoCard(
                  children: widget.selectedServices.map(_serviceCard).toList(),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: submitting ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _gold,
                    side: const BorderSide(color: _gold),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    translateText('Back'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setState(() => _localSubmitting = true);
                          try {
                            await widget.onSubmit();
                          } finally {
                            if (mounted) {
                              setState(() => _localSubmitting = false);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.starColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          submitLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
