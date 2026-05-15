import 'dart:io';

import 'package:bloc_onboarding/features/stylist_attendance/stylist_attendance_models.dart';
import 'package:bloc_onboarding/utils/localization_helper.dart';
import 'package:flutter/material.dart';

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
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF9F8),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('Your Stored Images'),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF1C1917),
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: kStylistAttendanceRequiredPoses.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final pose = kStylistAttendanceRequiredPoses[index];
          final imagePath = enrollment.imagePaths[pose.id];
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imagePath == null || imagePath.isEmpty
                        ? Container(
                            color: const Color(0xFFF5F5F4),
                            child: const Center(
                              child: Icon(
                                Icons.face_outlined,
                                color: Color(0xFFA8A29E),
                                size: 28,
                              ),
                            ),
                          )
                        : Image.file(
                            File(imagePath),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFFF5F5F4),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFFA8A29E),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pose.label.tr(context),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  pose.description.tr(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF78716C),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
