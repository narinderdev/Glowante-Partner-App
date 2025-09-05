import 'package:flutter/material.dart';

class TeamMemberDetails extends StatelessWidget {
  final Map<String, dynamic> member;

  const TeamMemberDetails({Key? key, required this.member}) : super(key: key);

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0] : '';
    final l = last.isNotEmpty ? last[0] : '';
    return (f + l).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final String firstName = (member['firstName'] ?? '').toString();
    final String lastName  = (member['lastName'] ?? '').toString();
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

    final borderColor = Colors.black.withOpacity(0.08);
    final cardRadius  = BorderRadius.circular(14);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Profile'),
        elevation: 0,
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
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 4),
                          Text(
                            role.isEmpty ? 'Hair' : role,
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => const Icon(
                                  Icons.star,
                                  size: 18,
                                  color: Color(0xFFFFB300),
                                ),
                              ),
                              const SizedBox(width: 6),
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
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Icon(Icons.more_horiz, color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Specializations
              _SectionCard(
                title: 'Specializations',
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

              const SizedBox(height: 12),

              // Experience
              _SectionCard(
                title: 'Experience',
                icon: Icons.work_outline,
                borderColor: borderColor,
                radius: cardRadius,
                trailing: Text(
                  experience,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),

              const SizedBox(height: 12),

              // Assigned Branches
              _SectionCard(
  title: 'Assigned Branches',
  icon: Icons.apartment_outlined,
  borderColor: borderColor,
  radius: cardRadius,
  // 👈 removed trailing from the card header
  child: Align(
    alignment: Alignment.centerLeft,
    child: branches.isEmpty
        ? const Text(
            'No branched assigned',
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
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 18, color: Colors.black54),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          branchName,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
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
)

            ],
          ),
        ),
      ),

      // 🔹 Sticky bottom button (outside scroll)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // TODO: handle assign
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD8B1F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Assign User',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
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
              const SizedBox(width: 10),
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
          if (hasChild) const SizedBox(height: 10),
          if (hasChild) child!,
        ],
      ),
    );
  }
}
