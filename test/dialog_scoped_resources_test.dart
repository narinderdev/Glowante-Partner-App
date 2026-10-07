import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bloc_onboarding/widgets/dialog_scoped_resources.dart';

// Mirrors _showAddClientDialog in owner_branch_all_clients_screen.dart:
// controllers are created outside showDialog and disposed in a finally block
// that runs as soon as the dialog route is popped.
class HostScreen extends StatefulWidget {
  const HostScreen({super.key});
  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  Future<void> _showAddClientDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => DialogScopedResources(
          resources: [nameController, phoneController],
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final maxDialogHeight = MediaQuery.of(context).size.height -
                  MediaQuery.of(context).viewInsets.bottom -
                  48;

              Future<void> submit() async {
                setDialogState(() => isSubmitting = true);
                await Future<void>.delayed(const Duration(milliseconds: 50));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (dialogContext.mounted) {
                  setDialogState(() => isSubmitting = false);
                }
              }

              return Dialog(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxDialogHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          onSubmitted: (_) =>
                              FocusScope.of(context).nextFocus(),
                        ),
                        TextField(
                          controller: phoneController,
                          onSubmitted: (_) => submit(),
                        ),
                        ElevatedButton(
                          onPressed: isSubmitting ? null : submit,
                          child: const Text('ADD CUSTOMER'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } finally {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _showAddClientDialog,
          child: const Text('Add Client'),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('dialog controllers outlive the pop-out transition',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HostScreen()));
    await tester.tap(find.text('Add Client'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Jane');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '9876543210');
    await tester.pump();

    await tester.tap(find.text('ADD CUSTOMER'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
  });
}
