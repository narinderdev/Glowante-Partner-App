// End-to-end onboarding flow, driven for real on a connected device via
// `flutter test integration_test/onboarding_flow_test.dart -d <deviceId>`.
//
// Built incrementally, phase by phase — see the numbered groups below.
// Test phone number / OTP are fixed test credentials for the dev backend.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:bloc_onboarding/main.dart' as app;

const String testPhoneNumber = '9878789898';
const String testOtp = '123456';

// The app shows a first-run onboarding carousel (Next... Next... Get
// Started) before Login, only when no session/onboarding flag is stored.
// Tap through it if present; no-op if we land straight on Login.
Future<void> _passOnboardingIfShown(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    if (find.text('Enter mobile number').evaluate().isNotEmpty) return;
    final button = find.byType(ElevatedButton);
    if (button.evaluate().isEmpty) return;
    await tester.tap(button.first);
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }
}

Future<void> _enterOtp(WidgetTester tester, String otp) async {
  final otpFields = find.byType(TextField);
  for (var i = 0; i < otp.length; i++) {
    await tester.enterText(otpFields.at(i), otp[i]);
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

// Scrolls an open dropdown menu (its Scrollable's own bounds can extend
// well past the visible viewport, so dragUntilVisible's auto-computed
// center often lands off-screen) by dragging from a fixed on-screen point
// until the target option's text appears in the tree, then taps it.
Future<void> _selectFromOpenDropdown(WidgetTester tester, String optionText) async {
  // dragFrom uses *logical* pixels (physicalSize / devicePixelRatio), not
  // raw device pixels — a hardcoded point sized for physical pixels can
  // land off-screen. Compute a safe on-screen point from the actual
  // logical view size instead.
  final logicalSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final start = Offset(logicalSize.width * 0.5, logicalSize.height * 0.6);

  for (var i = 0; i < 40; i++) {
    if (find.text(optionText).evaluate().isNotEmpty) break;
    await tester.dragFrom(start, const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.pumpAndSettle();
  expect(
    find.text(optionText),
    findsWidgets,
    reason: 'Dropdown option "$optionText" never scrolled into view',
  );
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 1 — Login + OTP verify', () {
    testWidgets('logs in with test phone number and verifies OTP',
        (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await _passOnboardingIfShown(tester);

      // Splash screen (+ onboarding carousel, if shown) should resolve to
      // the login screen.
      expect(find.text('Enter mobile number'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        testPhoneNumber,
      );
      await tester.pump();

      // "Login" button becomes enabled once a valid 10-digit number is
      // entered — tap it to request an OTP.
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should now be on the OTP screen.
      expect(find.text('Verify Your Number'), findsOneWidget);

      await _enterOtp(tester, testOtp);
      await tester.pumpAndSettle(const Duration(seconds: 8));

      // OTP screen should be gone — verification succeeded and we've
      // navigated onward (exact next screen depends on account state).
      expect(find.text('Verify Your Number'), findsNothing);

      // ---- Phase 2 — Update Profile ----
      // Only shown the first time (firstName/lastName still empty on the
      // account). On repeat runs against the same test account this screen
      // is skipped, so don't hard-require it.
      if (find.text('Enter your first name').evaluate().isNotEmpty) {
        await tester.enterText(
          find.byType(TextField).at(0),
          'Test',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          'Owner',
        );
        await tester.enterText(
          find.byType(TextField).at(2),
          'qa.owner.glowante@example.com',
        );
        await tester.pumpAndSettle();

        // Dismiss the on-screen keyboard first (tap an empty corner — the
        // app's root GestureDetector unfocuses on any non-field tap) so the
        // layout settles back and the Continue button is actually hit.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle(const Duration(seconds: 8));

        expect(find.text('Enter your first name'), findsNothing);
      }

      // ---- Phase 3 — Create Salon ----
      // Only shown when the account has no salon yet (fresh accounts land
      // here right after profile update). Skip if we're already past it.
      if (find.text('Enter your business name').evaluate().isNotEmpty) {
        await tester.enterText(
          find.byType(TextField).at(0),
          'QA Test Salon',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          '9123456780',
        );
        await tester.pumpAndSettle();

        // Start / End time — plain DropdownButton<String> widgets. The menu
        // is a long (144-entry, 10-min step) virtualized list, so the
        // target item may not be built yet — scroll to it first.
        await tester.tap(find.byType(DropdownButton<String>).at(0));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await _selectFromOpenDropdown(tester, '09:00 AM');

        await tester.tap(find.byType(DropdownButton<String>).at(1));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await _selectFromOpenDropdown(tester, '06:00 PM');

        // Address — opens a Google Places search screen. Search, pick the
        // first suggestion, confirm.
        await tester.tap(find.text('Add Location'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await tester.enterText(
          find.byType(TextField).first,
          'Connaught Place, New Delhi',
        );
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        final suggestion = find.byType(ListTile).first;
        await tester.tap(suggestion);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await tester.tap(find.text('CONFIRM LOCATION'));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Back on Salon Details — fill Description, then advance.
        await tester.enterText(
          find.byType(TextField).at(2),
          'QA automated test salon, please ignore.',
        );
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle(const Duration(seconds: 1));

        await tester.tap(find.text('Next Step'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Weekly schedule — defaults (every day open, salon hours) are
        // already valid; just continue.
        expect(find.text('Set Weekly Working Hours'), findsOneWidget);
        await tester.tap(find.text('Save & Continue'));
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Select Services — pick the first category card ("Hair").
        await tester.tap(find.text('Hair').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Finish & Launch Salon'));
        await tester.pumpAndSettle(const Duration(seconds: 10));

        expect(find.text('Finish & Launch Salon'), findsNothing);
      }
    });
  });
}
