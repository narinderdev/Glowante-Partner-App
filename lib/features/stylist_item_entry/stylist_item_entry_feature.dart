import 'package:flutter/material.dart';

import 'screens/stylist_item_scanner_screen.dart';
import 'screens/stylist_used_item_editor_screen.dart';
import 'stylist_used_item.dart';
import 'widgets/stylist_item_entry_dialog.dart';

export 'stylist_used_item.dart';

Future<StylistUsedItem?> showStylistItemEntryFlow(BuildContext context) async {
  final action = await showStylistItemEntryDialog(context);
  if (!context.mounted || action == null) return null;

  if (action == StylistItemEntryAction.scan) {
    return Navigator.of(context).push<StylistUsedItem>(
      MaterialPageRoute(
        builder: (_) => const StylistItemScannerScreen(),
      ),
    );
  }

  return Navigator.of(context).push<StylistUsedItem>(
    MaterialPageRoute(
      builder: (_) => const StylistUsedItemEditorScreen(
        title: 'Enter Item Details',
        submitLabel: 'Save Item',
        sourceLabel: 'Manual entry',
      ),
    ),
  );
}
