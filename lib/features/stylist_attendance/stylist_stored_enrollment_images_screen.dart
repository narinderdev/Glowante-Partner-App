import 'dart:io';

import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';

import '../profile/widgets/profile_subpage_app_bar.dart';

class StylistStoredEnrollmentImagesScreen extends StatelessWidget {
  const StylistStoredEnrollmentImagesScreen({
    super.key,
    required this.enrollment,
  });

  final StylistAttendanceEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F8),
      appBar: buildProfileSubpageAppBar(
        title: context.t('Your Stored Images'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _StoredImagesSummary(enrollment: enrollment),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: kStylistAttendanceRequiredPoses.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              final pose = kStylistAttendanceRequiredPoses[index];
              final imagePath = enrollment.imagePaths[pose.id];
              return _StoredImageTile(
                pose: pose,
                imagePath: imagePath,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StoredImagesSummary extends StatelessWidget {
  const _StoredImagesSummary({required this.enrollment});

  final StylistAttendanceEnrollment enrollment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1917),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${enrollment.completedCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Face Setup Images'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${enrollment.completedCount} / ${kStylistAttendanceRequiredPoses.length}',
                  style: const TextStyle(
                    color: Color(0xFF78716C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StoredImageTile extends StatelessWidget {
  const _StoredImageTile({
    required this.pose,
    required this.imagePath,
  });

  final StylistAttendancePose pose;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final hasImage = imagePath != null && imagePath!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F4),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: !hasImage
                  ? const Center(
                      child: Icon(
                        Icons.face_outlined,
                        color: Color(0xFFA8A29E),
                        size: 28,
                      ),
                    )
                  : Image.file(
                      File(imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFFA8A29E),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            pose.label.tr(context),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            pose.description.tr(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              color: Color(0xFF78716C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
