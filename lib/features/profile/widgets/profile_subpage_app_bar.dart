import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _profileSubpageBackground = Color(0xFFFBF9F8);
const Color _profileSubpageDivider = Color(0xFFF1EBE6);
const Color _profileSubpageTitle = Color(0xFFB45309);

TextStyle _profileSubpageTitleStyle() {
  return const TextStyle(
    fontFamily: 'Manrope',
    fontFamilyFallback: ['Inter', 'sans-serif'],
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: _profileSubpageTitle,
  );
}

AppBar buildProfileSubpageAppBar({
  required String title,
  bool centerTitle = true,
}) {
  return AppBar(
    backgroundColor: _profileSubpageBackground,
    elevation: 0,
    centerTitle: centerTitle,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    scrolledUnderElevation: 0,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    iconTheme: const IconThemeData(
      color: _profileSubpageTitle,
      size: 24,
    ),
    title: Text(
      title,
      style: _profileSubpageTitleStyle(),
    ),
    bottom: const PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(
        height: 1,
        thickness: 1,
        color: _profileSubpageDivider,
      ),
    ),
  );
}
