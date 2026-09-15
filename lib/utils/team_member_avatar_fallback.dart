const String maleTeamMemberAvatarAsset = 'assets/images/male.png';
const String femaleTeamMemberAvatarAsset = 'assets/images/female.png';

String _cleanTeamMemberAvatarText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.toLowerCase() == 'null' ? '' : text;
}

String teamMemberGenderFromMap(Map<dynamic, dynamic> map) {
  for (final key in const ['gender', 'sex']) {
    final text = _cleanTeamMemberAvatarText(map[key]);
    if (text.isNotEmpty) return text;
  }

  for (final key in const ['profile', 'user', 'member', 'professional']) {
    final nested = map[key];
    if (nested is Map) {
      final gender = teamMemberGenderFromMap(nested);
      if (gender.isNotEmpty) return gender;
    }
  }

  for (final key in const ['branches', 'userBranches', 'assignments']) {
    final nestedList = map[key];
    if (nestedList is List) {
      for (final nested in nestedList) {
        if (nested is Map) {
          final gender = teamMemberGenderFromMap(nested);
          if (gender.isNotEmpty) return gender;
        }
      }
    }
  }

  return '';
}

String? teamMemberAvatarAssetForGender(dynamic gender) {
  final text = _cleanTeamMemberAvatarText(gender)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z]'), '');
  if (text.isEmpty) return null;
  if (text == 'female' || text == 'f' || text == 'woman' || text == 'women') {
    return femaleTeamMemberAvatarAsset;
  }
  if (text == 'male' || text == 'm' || text == 'man' || text == 'men') {
    return maleTeamMemberAvatarAsset;
  }
  return null;
}
