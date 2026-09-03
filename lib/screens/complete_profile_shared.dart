import 'package:flutter/material.dart';

import 'package:bloc_onboarding/utils/localization_helper.dart';

const Color cpAccent = Color(0xFFC19A6B);
const Color cpAccentLight = Color(0xFFF3E8D1);
const Color cpInk = Color(0xFF1C1917);
const Color cpMuted = Color(0xFF78716C);
const Color cpBorder = Color(0xFFE7E5E4);
const Color cpSurface = Color(0xFFFAF8F5);

bool cpIsFilled(dynamic value) =>
    value != null && value.toString().trim().isNotEmpty;

/// Carries the fetched server profile plus every field the user fills in
/// across the four Complete Profile steps. Passed by reference from step to
/// step (each screen mutates it directly) and only turned into a PATCH
/// body — via [CompleteProfileDraft.buildPatchFields] — on the final step,
/// per salon_team_part_2.md's fill-missing-only, all-or-nothing semantics.
class CompleteProfileDraft {
  CompleteProfileDraft({
    required this.salonId,
    required this.userId,
    required this.profile,
    required this.specialityOptions,
  });

  final int salonId;
  final int userId;

  /// Server truth from GET .../team/{userId} — the source for which
  /// fields are already populated (and therefore locked) on every step.
  final Map<String, dynamic> profile;
  final List<Map<String, dynamic>> specialityOptions;

  String firstName = '';
  String lastName = '';
  String? gender;
  DateTime? careerStartDate;
  String bio = '';
  final Set<String> specialityCodes = {};

  String line1 = '';
  String line2 = '';
  String city = '';
  String village = '';
  String district = '';
  String state = '';
  String country = '';
  String postalCode = '';
  double? latitude;
  double? longitude;

  bool get hasFirstName => cpIsFilled(profile['firstName']);
  bool get hasLastName => cpIsFilled(profile['lastName']);
  bool get hasGender => cpIsFilled(profile['gender']);
  bool get hasCareerStartDate => cpIsFilled(profile['careerStartDate']);
  bool get hasBio => cpIsFilled(profile['bio']);
  bool get hasSpecialities {
    final raw = profile['specialities'];
    return raw is List && raw.isNotEmpty;
  }

  // address is always the complete object or null (updated_3 §5.2, part_2
  // §8) — never partial, never redacted — so key presence alone is the
  // correctness signal, not any individual sub-field.
  bool get hasAddress => profile['address'] != null;
  bool get hasAvatar => cpIsFilled(profile['profilePictureUrl']);

  // updated_3 §5.4's exact isProfileComplete formula, spelled out so the
  // salon can see precisely why a member is still Setup Required — a
  // member can have every salon-fillable field populated and still show
  // Setup Required, because phoneVerified/emailVerified are the member's
  // own responsibility (self-service, not something a salon can PATCH).
  List<String> missingForActiveStatus() {
    final missing = <String>[];
    if (!hasFirstName) missing.add(translateText('First name'));
    if (!hasLastName) missing.add(translateText('Last name'));
    if (profile['phoneVerified'] != true) {
      missing.add(translateText('Phone verification (member must verify)'));
    }
    if (profile['emailVerified'] != true) {
      missing.add(translateText('Email verification (member must verify)'));
    }
    if (!hasGender) missing.add(translateText('Gender'));
    if (!hasAddress) missing.add(translateText('Address'));
    if (!hasBio) missing.add(translateText('Bio'));
    return missing;
  }

  Map<String, dynamic> get address {
    final raw = profile['address'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  void prefillFromProfile() {
    firstName = (profile['firstName'] ?? '').toString();
    lastName = (profile['lastName'] ?? '').toString();
    bio = (profile['bio'] ?? '').toString();
    gender = hasGender ? (profile['gender'] ?? '').toString() : null;

    final careerStartDateRaw = (profile['careerStartDate'] ?? '').toString();
    if (careerStartDateRaw.trim().isNotEmpty) {
      careerStartDate = DateTime.tryParse(careerStartDateRaw.trim());
    }

    final addr = address;
    line1 = (addr['line1'] ?? '').toString();
    line2 = (addr['line2'] ?? '').toString();
    city = (addr['city'] ?? '').toString();
    village = (addr['village'] ?? '').toString();
    district = (addr['district'] ?? '').toString();
    state = (addr['state'] ?? '').toString();
    country = (addr['country'] ?? '').toString();
    postalCode = (addr['postalCode'] ?? '').toString();

    if (hasSpecialities) {
      final raw = profile['specialities'];
      if (raw is List) {
        for (final entry in raw) {
          final code = entry is Map ? entry['code'] : entry;
          if (code != null) specialityCodes.add(code.toString());
        }
      }
    }
  }

  // updated_3 §5.2: line1, (city OR village), state, country, postalCode
  // are all required for a stored address to count as complete — an
  // incomplete one is simply dropped by the server (rendered as `address:
  // null` on the next GET), so it's better to catch that client-side with
  // a clear message than to silently lose what the user typed.
  String? addressCompletionError() {
    if (hasAddress || line1.trim().isEmpty) return null;
    final missing = <String>[];
    if (city.trim().isEmpty && village.trim().isEmpty) {
      missing.add(translateText('City or Village'));
    }
    if (state.trim().isEmpty) missing.add(translateText('State'));
    if (country.trim().isEmpty) missing.add(translateText('Country'));
    if (postalCode.trim().isEmpty) missing.add(translateText('Postal code'));
    if (missing.isEmpty) return null;
    return translateText(
      'Address is missing: {fields}',
      params: {'fields': missing.join(', ')},
    );
  }

  Map<String, dynamic> buildPatchFields() {
    final fields = <String, dynamic>{};

    if (!hasFirstName && firstName.trim().isNotEmpty) {
      fields['firstName'] = firstName.trim();
    }
    if (!hasLastName && lastName.trim().isNotEmpty) {
      fields['lastName'] = lastName.trim();
    }
    if (!hasGender && gender != null && gender!.trim().isNotEmpty) {
      fields['gender'] = gender;
    }
    if (!hasCareerStartDate && careerStartDate != null) {
      final d = careerStartDate!;
      fields['careerStartDate'] =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    if (!hasBio && bio.trim().isNotEmpty) {
      fields['bio'] = bio.trim();
    }
    if (!hasSpecialities && specialityCodes.isNotEmpty) {
      fields['specialities'] = specialityCodes.toList();
    }
    if (!hasAddress && line1.trim().isNotEmpty) {
      final trimmedLine1 = line1.trim();
      final trimmedLine2 = line2.trim();
      final trimmedDistrict = district.trim();
      fields['address'] = {
        'line1': trimmedLine1,
        if (trimmedLine2.isNotEmpty) 'line2': trimmedLine2,
        'city': city.trim(),
        'village': village.trim(),
        if (trimmedDistrict.isNotEmpty) 'district': trimmedDistrict,
        'state': state.trim(),
        'country': country.trim(),
        'postalCode': postalCode.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'formattedAddress': trimmedLine1,
      };
    }

    return fields;
  }
}

InputDecoration cpInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: cpMuted, fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: cpBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: cpBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: cpAccent, width: 1.4),
    ),
  );
}

// Plain section header + its fields, flowing directly on the screen — no
// bordered/shadowed card box around each group, so the whole step reads as
// one continuous screen rather than a stack of separate cards.
class CpSectionCard extends StatelessWidget {
  const CpSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cpAccentLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 15, color: cpAccent),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              title,
              style: const TextStyle(
                color: cpInk,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// A thin rule between two sections on the same screen — the only visual
/// separator now that sections aren't individually boxed cards.
class CpSectionDivider extends StatelessWidget {
  const CpSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Divider(height: 1, thickness: 1, color: cpBorder),
    );
  }
}

/// Per-step title + description, matching select_services_AssignUser.dart's
/// "Choose Services" heading pattern, so every step reads like a distinct
/// screen with its own purpose rather than a bare form.
class CpStepHeading extends StatelessWidget {
  const CpStepHeading({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF8B6500),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: cpMuted),
        ),
      ],
    );
  }
}

// Wraps an editable field, swapping it for a locked read-only display once
// the server already has a value — salon_team_part_2.md: a populated field
// can never be overwritten by a salon actor, only an empty one can be filled.
class CpLockableField extends StatelessWidget {
  const CpLockableField({
    super.key,
    required this.label,
    required this.isLocked,
    required this.lockedValue,
    required this.child,
  });

  final String label;
  final bool isLocked;
  final String? lockedValue;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;
    return CpLockedValueChip(
      value: (lockedValue ?? '').trim().isEmpty
          ? translateText('Not set')
          : lockedValue!.trim(),
    );
  }
}

class CpLockedValueChip extends StatelessWidget {
  const CpLockedValueChip({super.key, required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cpSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cpBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cpBorder),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.lock_outline_rounded,
                size: 13, color: cpMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? translateText('Not set') : value,
              style: const TextStyle(
                color: cpInk,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            translateText('Locked'),
            style: const TextStyle(
              color: cpMuted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class CpErrorState extends StatelessWidget {
  const CpErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: cpInk, fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(translateText('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class CpBottomButton extends StatelessWidget {
  const CpBottomButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
    this.onBack,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onPressed;

  /// When set, renders a Back + [label] button row — matching Assign
  /// User's step bottom bar (select_services_AssignUser.dart) — instead
  /// of a single full-width button.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final continueButton = SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isBusy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B6500),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isBusy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );

    final onBack = this.onBack;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: onBack == null
          ? continueButton
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: isBusy ? null : onBack,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: cpAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        translateText('Back'),
                        style: const TextStyle(
                          color: cpAccent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: continueButton),
              ],
            ),
    );
  }
}

// Matches select_services_AssignUser.dart's _ServiceSelectionMark — a
// small rounded checkbox indicator — for a consistent selection UI
// across the app's multi-step flows.
class CpSelectionMark extends StatelessWidget {
  const CpSelectionMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? cpAccent : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? cpAccent : cpBorder,
          width: 1.3,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

// Matches select_services_AssignUser.dart's row-item look: a bordered
// tile, gold-tinted when selected, with the checkbox mark on the left.
class CpSelectableRow extends StatelessWidget {
  const CpSelectableRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color:
              selected ? cpAccentLight.withValues(alpha: 0.35) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? cpAccent : cpBorder),
        ),
        child: Row(
          children: [
            CpSelectionMark(selected: selected),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cpInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CpCountPill extends StatelessWidget {
  const CpCountPill({super.key, required this.selected, required this.total});

  final int selected;
  final int total;

  @override
  Widget build(BuildContext context) {
    final active = selected > 0;
    final color = active ? cpAccent : cpMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$selected/$total',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}
