import 'package:flutter/material.dart';

import '../stylist_item_entry_theme.dart';

enum StylistItemEntryAction { scan, manual }

Future<StylistItemEntryAction?> showStylistItemEntryDialog(
  BuildContext context,
) {
  return showDialog<StylistItemEntryAction>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const StylistItemEntryDialog(),
  );
}

class StylistItemEntryDialog extends StatelessWidget {
  const StylistItemEntryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: stylistItemBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: stylistItemAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: stylistItemAccent,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add items used',
                    style: TextStyle(
                      color: stylistItemPrimaryText,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: stylistItemBorder),
            const SizedBox(height: 14),
            _EntryActionCard(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan',
              description: 'Open camera and scan a barcode or QR code.',
              onTap: () {
                Navigator.of(context).pop(StylistItemEntryAction.scan);
              },
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: stylistItemBorder),
            const SizedBox(height: 12),
            _EntryActionCard(
              icon: Icons.edit_note_rounded,
              title: 'Enter Details',
              description: 'Fill the item details manually on the next screen.',
              onTap: () {
                Navigator.of(context).pop(StylistItemEntryAction.manual);
              },
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: stylistItemBorder),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: stylistItemSecondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryActionCard extends StatelessWidget {
  const _EntryActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: stylistItemBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: stylistItemBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: stylistItemBorder),
              ),
              child: Icon(icon, color: stylistItemAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: stylistItemPrimaryText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: stylistItemSecondaryText,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: stylistItemSecondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
