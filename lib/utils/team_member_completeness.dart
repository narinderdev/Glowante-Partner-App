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

List<String> _roleTexts(Map<String, dynamic> member) {
  final labels = <String>[];
  final assignment = _primaryBranchAssignment(member);

  void addLabel(dynamic raw) {
    if (raw is List) {
      for (final item in raw) {
        addLabel(item);
      }
      return;
    }
    if (raw is! Map) {
      final label = raw?.toString().trim() ?? '';
      if (label.isEmpty || label.toLowerCase() == 'null') return;
      final normalized = label.toLowerCase();
      if (!labels.contains(normalized)) {
        labels.add(normalized);
      }
      return;
    }
    final label =
        (raw['label'] ?? raw['name'] ?? raw['code'] ?? '').toString().trim();
    if (label.isEmpty || label.toLowerCase() == 'null') return;
    final normalized = label.toLowerCase();
    if (!labels.contains(normalized)) {
      labels.add(normalized);
    }
  }

  addLabel(member['roles']);
  addLabel(member['roleCodes']);
  addLabel(member['roleIds']);
  addLabel(member['role']);
  if (assignment != null) {
    addLabel(assignment['roles']);
    addLabel(assignment['roleCodes']);
    addLabel(assignment['roleIds']);
    addLabel(assignment['role']);
    addLabel(assignment['professionalStatus']);
  }
  return labels;
}

/// Every field AddTeam.dart's own validators treat as compulsory
/// (`_vPhone`, `_vFirstName`/`_vLastName`, `_vEmail`, `_vAddress`,
/// `_vGender`, `_vRoles`, `_vSpecs`, `_vJoiningDate`, `_vBrief`,
/// `_vExperience`) — checked here regardless of role, since these are
/// required for any team member, not just stylists. Shared between the
/// team list card and the Assign User flow so both apply the same rule.
List<String> computeTeamMemberMissingFields(Map<String, dynamic> member) {
  final missing = <String>[];
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
  final gender = _cleanText(
    assignment?['gender'] ??
        assignment?['sex'] ??
        member['gender'] ??
        member['sex'],
  );
  final info = _cleanText(
    assignment?['info'] ??
        assignment?['brief'] ??
        member['info'] ??
        member['brief'] ??
        member['bio'] ??
        member['about'],
  );
  final experience =
      _cleanText(assignment?['experience'] ?? member['experience']);
  final joiningDate = _cleanText(
    assignment?['joiningDate'] ?? member['joiningDate'],
  );
  final branchServices = assignment?['userBranchServices'] ??
      assignment?['branchServiceIds'] ??
      member['userBranchServices'] ??
      member['branchServiceIds'] ??
      member['services'];
  final specialities = assignment?['specialities'] ??
      assignment?['specializations'] ??
      assignment?['specialties'] ??
      member['specialities'] ??
      member['specializations'] ??
      member['specialties'] ??
      member['specialitiesList'] ??
      member['specializationsList'] ??
      member['specialtiesList'];
  final address = _cleanText(assignment?['address'] ?? member['address']);

  if (firstName.isEmpty || lastName.isEmpty) {
    missing.add('name');
  }
  if (phone.isEmpty) {
    missing.add('phone');
  }
  if (email.isEmpty) {
    missing.add('email');
  }
  if (gender.isEmpty) {
    missing.add('gender');
  }
  if (_roleTexts(member).isEmpty) {
    missing.add('role');
  }
  if (experience.isEmpty) {
    missing.add('experience');
  }
  if (joiningDate.isEmpty) {
    missing.add('joining date');
  }
  if (info.isEmpty) {
    missing.add('about');
  }
  if (address.isEmpty) {
    missing.add('address');
  }
  if (branchServices is! List || branchServices.isEmpty) {
    missing.add('services');
  }
  if (specialities is! List || specialities.isEmpty) {
    missing.add('specializations');
  }

  return missing;
}

bool teamMemberNeedsSetupCompletion(Map<String, dynamic> member) =>
    computeTeamMemberMissingFields(member).isNotEmpty;
