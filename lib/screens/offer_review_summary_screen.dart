import 'package:flutter/material.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

class OfferReviewSummaryScreen extends StatelessWidget {
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              translateText(label),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value.trim(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _discountLabel {
    if (pricingMode == 'Fixed') return 'Amount Off';
    if (discountType == 'Percent') return 'Percentage Off';
    return 'Amount Off';
  }

  String get _discountValue {
    if (pricingMode == 'Fixed') return '₹$amountOff';
    if (discountType == 'Percent') return '$amountOff%';
    return '₹$amountOff';
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = isPackage
        ? translateText('Package Summary')
        : translateText('Deal Summary');

    final submitLabel = isEdit
        ? isPackage
            ? translateText('Update Package')
            : translateText('Update Deal')
        : isPackage
            ? translateText('Create Package')
            : translateText('Create Deal');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: pageTitle,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                translateText('Review Summary'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 18),

              _row(isPackage ? 'Package Title' : 'Deal Title', title),
              _row('Pricing Option', pricingMode),

              if (pricingMode == 'Discount') _row('Discount Type', discountType),

              _row(_discountLabel, _discountValue),

              if (pricingMode == 'Discount' && discountType == 'Percent')
                _row('Max Discount', '₹$maxDiscount'),

              _row('Original Price', '₹$originalPrice'),
              _row('Discounted Price', '₹$discountedPrice'),
              _row('Terms', terms),

              if (isPackage)
                _row('Duration', '$durationValue $durationUnit')
              else ...[
                _row('Start Date', validFrom),
                _row('End Date', validTill),
              ],

              const SizedBox(height: 18),

              Text(
                translateText('Selected Services'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),

              if (selectedServices.isEmpty)
                Text(
                  translateText('No services selected'),
                  style: const TextStyle(color: Colors.black54),
                )
              else
                ...selectedServices.map((service) {
                  final name = (service['name'] ?? '').toString();
                  final price = (service['price'] ?? 0).toString();
                  final qty = (service['qty'] ?? 0).toString();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          'Qty: $qty  ₹$price',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

              const SizedBox(height: 28),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(translateText('Back')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.starColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: isSubmitting
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
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