import 'package:flutter/material.dart';
import 'AssignUser.dart';
import '../screens/AssignUser.dart';
import 'package:flutter/services.dart';
import '../utils/colors.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import '../utils/colors.dart';
import 'package:flutter/services.dart';
import '../features/profile/widgets/profile_subpage_app_bar.dart';

class TeamMemberDetails extends StatelessWidget {
  final Map<String, dynamic> member;
  final List<Map<String, dynamic>>? salons; // 👈 new
  const TeamMemberDetails({
    Key? key,
    required this.member,
    this.salons,
  }) : super(key: key);

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    return (f + l).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = (member['firstName'] ?? '').toString();
    final String lastName = (member['lastName'] ?? '').toString();
    final userId = member['id'];
    final String name = (firstName + ' ' + lastName).trim();
    final String role = (member['roles'] != null && member['roles'].isNotEmpty)
        ? member['roles'][0]['label']?.toString() ?? 'Staff'
        : 'Staff';
    final String specialization =
        (member['specialities'] != null && member['specialities'].isNotEmpty)
            ? member['specialities'][0]['name']?.toString() ?? 'Hair'
            : 'Hair';
    final String rating = '4.5';
    final String experience = member['experience']?.toString() ?? '3 years';
    final List branches = (member['userBranches'] ?? []) as List;
    final List userSalons = (member['userSalons'] ?? []) as List;
    final List userBranches = (member['userBranches'] ?? []) as List;
    final String joinedAt = userBranches.isNotEmpty
        ? (userBranches[0]['joiningDate'] ?? 'N/A').toString()
        : 'N/A';

    final borderColor = Colors.black.withOpacity(0.08);
    final cardRadius = BorderRadius.circular(14);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: buildProfileSubpageAppBar(
        title: translateText('View Member'),
      ),
      // 🔹 Scrollable content
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F3FF), Color(0xFFFDFBF7)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Top profile card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: cardRadius,
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFFFE7C2),
                      child: Text(
                        _initials(firstName, lastName).isEmpty
                            ? 'MS'
                            : _initials(firstName, lastName),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Madhavi Singh' : name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            role.isEmpty ? 'Hair' : role,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Color(0xFFFFB300),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(rating,
                                  style: const TextStyle(
                                      fontSize: 14, color: Colors.black87)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {},
                        child: Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.more_horiz, color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),
// Text("Assign User ($userId)"),
              // Specializations
              _SectionCard(
                title: translateText('Specializations'),
                icon: Icons.emoji_objects_outlined,
                borderColor: borderColor,
                radius: cardRadius,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(specialization),
                        backgroundColor: const Color(0xFFF4F4F6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 12),

              // Experience
              _SectionCard(
                title: translateText('Experience'),
                icon: Icons.work_outline,
                borderColor: borderColor,
                radius: cardRadius,
                trailing: Text(
                  experience,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),

              SizedBox(height: 12),
              _SectionCard(
                title: translateText('Joined At'),
                icon: Icons.calendar_today_outlined,
                borderColor: borderColor,
                radius: cardRadius,
                trailing: Text(
                  joinedAt,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),

              SizedBox(height: 12),
              // Assigned Branches
              _SectionCard(
                title: translateText('Assigned Branches'),
                icon: Icons.apartment_outlined,
                borderColor: borderColor,
                radius: cardRadius,
                // 👈 removed trailing from the card header
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: branches.isEmpty
                      ? Text(
                          translateText('No branched assigned'),
                          style: TextStyle(color: Colors.black54),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: branches.map((b) {
                            final br = (b as Map)['branch'] as Map?;
                            final branchName = (br?['name'] ?? '').toString();

                            return InkWell(
                              onTap: () {
                                // TODO: handle branch row tap if you want
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 18, color: Colors.black54),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        branchName,
                                        style: const TextStyle(fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 22,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}

/// Reusable section container to match the card look in your mock.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? child;
  final Widget? trailing;
  final Color borderColor;
  final BorderRadius radius;

  const _SectionCard({
    Key? key,
    required this.title,
    required this.icon,
    this.child,
    this.trailing,
    required this.borderColor,
    required this.radius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasChild = child != null;
    final hasTrailing = trailing != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.black87),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              if (hasTrailing) trailing!,
            ],
          ),
          if (hasChild) SizedBox(height: 10),
          if (hasChild) child!,
        ],
      ),
    );
  }
}
