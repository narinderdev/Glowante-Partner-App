import 'package:flutter/material.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';

import '../../stylist_item_entry/stylist_used_item.dart';

const String _detailsFontFamily = 'Manrope';
const Color _detailsAccent = Color(0xFFC19A6B);
const Color _detailsPrimaryText = Color(0xFF1C1917);
const Color _detailsSecondaryText = Color(0xFF78716C);
const Color _detailsDateText = Color(0xFF44403C);
const Color _detailsUpcoming = Color(0xFF475569);
const Color _detailsPage = Color(0xFFFBF9F8);
const Color _detailsBorder = Color(0xFFE7E5E4);

TextStyle _detailsTextStyle({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = _detailsPrimaryText,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: _detailsFontFamily,
    fontFamilyFallback: const ['Inter'],
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

Color _elapsedValueColor({
  required String statusCode,
  required int elapsedMinutes,
  required int scheduledMinutes,
}) {
  final normalizedStatus = statusCode.trim().toUpperCase();
  if (normalizedStatus != 'IN_PROGRESS' && normalizedStatus != 'COMPLETED') {
    return _detailsSecondaryText;
  }
  if (scheduledMinutes > 0 && elapsedMinutes > scheduledMinutes) {
    return const Color(0xFFEF4444);
  }
  return _detailsAccent;
}

class StylistAppointmentServiceSegment {
  const StylistAppointmentServiceSegment({
    required this.title,
    required this.timeLabel,
    this.metaLabel,
  });

  final String title;
  final String timeLabel;
  final String? metaLabel;
}

class StylistAppointmentPreferenceData {
  const StylistAppointmentPreferenceData({
    required this.title,
    required this.dateLabel,
  });

  final String title;
  final String dateLabel;
}

class StylistAppointmentDetailsComponent extends StatelessWidget {
  const StylistAppointmentDetailsComponent({
    super.key,
    required this.onBack,
    required this.statusHeadline,
    required this.statusCode,
    required this.statusLabel,
    required this.statusPillBackgroundColor,
    required this.statusPillBorderColor,
    required this.statusPillTextColor,
    required this.elapsedClock,
    required this.progress,
    required this.elapsedMinutes,
    required this.scheduledMinutes,
    required this.timeRange,
    required this.serviceSummary,
    required this.assignedStaffLabel,
    required this.serviceSegments,
    required this.preferences,
    required this.totalAmount,
    required this.primaryAction,
    required this.primaryActionColor,
    required this.isPrimaryLoading,
    required this.onPrimaryAction,
    required this.addedItems,
    required this.onAddItems,
  });

  final VoidCallback onBack;
  final String statusHeadline;
  final String statusCode;
  final String statusLabel;
  final Color statusPillBackgroundColor;
  final Color statusPillBorderColor;
  final Color statusPillTextColor;
  final String elapsedClock;
  final double progress;
  final int elapsedMinutes;
  final int scheduledMinutes;
  final String timeRange;
  final String serviceSummary;
  final String assignedStaffLabel;
  final List<StylistAppointmentServiceSegment> serviceSegments;
  final List<StylistAppointmentPreferenceData> preferences;
  final String totalAmount;
  final String? primaryAction;
  final Color primaryActionColor;
  final bool isPrimaryLoading;
  final VoidCallback? onPrimaryAction;
  final List<StylistUsedItem> addedItems;
  final VoidCallback onAddItems;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _detailsPage,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: _detailsPrimaryText,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.t('Appointment Details'),
                      style: _detailsTextStyle(
                        size: 18,
                        weight: FontWeight.w600,
                        color: _detailsPrimaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Divider(
              height: 1,
              thickness: 1,
              color: _detailsBorder,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _DetailSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.t('Services').toUpperCase(),
                                style: _detailsTextStyle(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: _detailsSecondaryText,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Text(
                              '($timeRange)',
                              style: _detailsTextStyle(
                                size: 12,
                                weight: FontWeight.w700,
                                color: _detailsAccent,
                              ),
                            ),
                          ],
                        ),
                        if (assignedStaffLabel.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.badge_outlined,
                                size: 16,
                                color: _detailsSecondaryText,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${context.t('Assigned To')}: $assignedStaffLabel',
                                  style: _detailsTextStyle(
                                    size: 12,
                                    weight: FontWeight.w600,
                                    color: _detailsSecondaryText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        ...serviceSegments.asMap().entries.map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      entry.key == serviceSegments.length - 1
                                          ? 0
                                          : 10,
                                ),
                                child: _DetailServiceRow(
                                  segment: entry.value,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7DED3)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Color(0x10C19A6B),
                          blurRadius: 10,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          elapsedClock,
                          style: _detailsTextStyle(
                            size: 24,
                            weight: FontWeight.w700,
                            color: _detailsPrimaryText,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _ElapsedTimelineBar(
                          statusCode: statusCode,
                          elapsedMinutes: elapsedMinutes,
                          scheduledMinutes: scheduledMinutes,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${elapsedMinutes}m',
                                style: _detailsTextStyle(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: _elapsedValueColor(
                                    statusCode: statusCode,
                                    elapsedMinutes: elapsedMinutes,
                                    scheduledMinutes: scheduledMinutes,
                                  ),
                                ),
                              ),
                            ),
                            Text(
                              '${context.t('Total Time')}: ${scheduledMinutes}m',
                              style: _detailsTextStyle(
                                size: 11,
                                weight: FontWeight.w600,
                                color: _detailsSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (primaryAction != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPrimaryLoading ? null : onPrimaryAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryActionColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(52),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isPrimaryLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (primaryAction ==
                                      context
                                          .t('Finish Job')
                                          .toUpperCase()) ...[
                                    Image.asset(
                                      'assets/images/checkmark.png',
                                      width: 18,
                                      height: 18,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    primaryAction!,
                                    style: _detailsTextStyle(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE6DFD7)),
                      ),
                      child: Text(
                        statusLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _detailsUpcoming,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  if (addedItems.isNotEmpty) ...[
                    _DetailSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('Items Used').toUpperCase(),
                            style: _detailsTextStyle(
                              size: 12,
                              weight: FontWeight.w700,
                              color: _detailsSecondaryText,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...addedItems.asMap().entries.map(
                                (entry) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: entry.key == addedItems.length - 1
                                        ? 0
                                        : 10,
                                  ),
                                  child: _UsedItemSummaryCard(
                                    item: entry.value,
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onAddItems,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: _detailsAccent,
                        side: const BorderSide(color: _detailsAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.t('Add Items').toUpperCase(),
                        style: _detailsTextStyle(
                          size: 13,
                          weight: FontWeight.w700,
                          color: _detailsAccent,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElapsedTimelineBar extends StatelessWidget {
  const _ElapsedTimelineBar({
    required this.statusCode,
    required this.elapsedMinutes,
    required this.scheduledMinutes,
  });

  final String statusCode;
  final int elapsedMinutes;
  final int scheduledMinutes;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = statusCode.trim().toUpperCase();
    final isUpcoming =
        normalizedStatus != 'IN_PROGRESS' && normalizedStatus != 'COMPLETED';
    final safeScheduledMinutes = scheduledMinutes <= 0 ? 1 : scheduledMinutes;
    final normalizedElapsed =
        safeScheduledMinutes <= 0 ? 0.0 : elapsedMinutes / safeScheduledMinutes;
    final baseFillFraction =
        isUpcoming ? 0.0 : normalizedElapsed.clamp(0.0, 1.0).toDouble();
    final overtimeFraction = isUpcoming
        ? 0.0
        : ((elapsedMinutes - scheduledMinutes) / safeScheduledMinutes)
            .clamp(0.0, 1.0)
            .toDouble();

    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: const Color(0xFFE2DDD7)),
            if (baseFillFraction > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: baseFillFraction,
                  child: Container(color: _detailsAccent),
                ),
              ),
            if (overtimeFraction > 0)
              Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: overtimeFraction,
                  child: Container(color: const Color(0xFFEF4444)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailSectionCard extends StatelessWidget {
  const _DetailSectionCard({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _detailsBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 6,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailServiceRow extends StatelessWidget {
  const _DetailServiceRow({
    required this.segment,
  });

  final StylistAppointmentServiceSegment segment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _detailsBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3ECDD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.content_cut_rounded,
              color: _detailsAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  segment.title,
                  style: _detailsTextStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: _detailsPrimaryText,
                  ),
                ),
                if ((segment.metaLabel ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    segment.metaLabel!,
                    style: _detailsTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: _detailsSecondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '(${segment.timeLabel})',
            textAlign: TextAlign.right,
            style: _detailsTextStyle(
              size: 12,
              weight: FontWeight.w700,
              color: _detailsAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsedItemSummaryCard extends StatelessWidget {
  const _UsedItemSummaryCard({
    required this.item,
  });

  final StylistUsedItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _detailsBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF3ECDD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _detailsAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: _detailsTextStyle(
                    size: 14,
                    weight: FontWeight.w700,
                    color: _detailsPrimaryText,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: _detailsTextStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: _detailsSecondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (item.quantityLabel.trim().isNotEmpty ||
                    item.sourceLabel.trim().isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (item.quantityLabel.trim().isNotEmpty)
                        _UsedItemChip(label: item.quantityLabel),
                      if (item.sourceLabel.trim().isNotEmpty)
                        _UsedItemChip(label: context.t(item.sourceLabel)),
                    ],
                  ),
                if (item.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.notes,
                    style: _detailsTextStyle(
                      size: 12,
                      weight: FontWeight.w500,
                      color: _detailsDateText,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsedItemChip extends StatelessWidget {
  const _UsedItemChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _detailsBorder),
      ),
      child: Text(
        label,
        style: _detailsTextStyle(
          size: 11,
          weight: FontWeight.w700,
          color: _detailsSecondaryText,
        ),
      ),
    );
  }
}
