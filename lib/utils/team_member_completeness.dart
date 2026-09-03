String _cleanText(dynamic value) {
  return (value?.toString() ?? '').trim();
}

Map<String, dynamic>? _primaryBranchAssignment(Map<String, dynamic> member) {
  final branches = member['userBranches'];
  if (branches is! List || branches.isEmpty) return null;
  for (final rawBranch in branches) {
    if (rawBranch is Map) {
      return Map<String, dynamic>.from(rawBranch);
    }
  }
  return null;
}

/// The team list card no longer shows a "Setup incomplete" nudge — the old
/// direct "Add Team Member" flow (AddTeam.dart) collected gender, an
/// about/bio blurb, address, specializations, role, experience, joining
/// date and services up front, so flagging any of those as missing meant
/// something the owner could actually go fix. That flow is gone: invite
/// only collects name/phone/email, and the rest is optional going forward,
/// so there's nothing left worth nagging about post-assignment.
///
/// This still gates *starting* the assign-to-branch flow, checking only
/// what the invite step (InviteTeamMemberScreen) collects up front —
/// role, experience, joining date and services are collected *during*
/// that same flow (later screens in the AssignUser.dart → ... →
/// TeamOnlineAvailabilityScreen chain), so checking for them before the
/// flow even starts would always fail and block every first-time
/// assignment.
List<String> computeTeamMemberPreAssignMissingFields(
  Map<String, dynamic> member,
) {
  final firstName = _cleanText(member['firstName']);
  final lastName = _cleanText(member['lastName']);
  final email = _cleanText(member['email']);
  final assignment = _primaryBranchAssignment(member);
  final phone = _cleanText(
    assignment?['phoneNumber'] ??
        assignment?['phone'] ??
        member['phoneNumber'] ??
        member['phone'],
  );

  final missing = <String>[];
  if (firstName.isEmpty || lastName.isEmpty) {
    missing.add('name');
  }
  if (phone.isEmpty) {
    missing.add('phone');
  }
  if (email.isEmpty) {
    missing.add('email');
  }
  return missing;
}

bool teamMemberNeedsPreAssignCompletion(Map<String, dynamic> member) =>
    computeTeamMemberPreAssignMissingFields(member).isNotEmpty;
