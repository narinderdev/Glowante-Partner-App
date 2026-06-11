import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _profileSubpageBackground = Colors.white;
const Color _profileSubpageDivider = Color(0xFFF1EBE6);
const Color _profileSubpageTitle = Color(0xFF8B6500);

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
  bool centerTitle = false,
  bool automaticallyImplyLeading = true,
  double toolbarHeight = kToolbarHeight,
  List<Widget>? actions,
}) {
  return AppBar(
    backgroundColor: _profileSubpageBackground,
    toolbarHeight: toolbarHeight,
    elevation: 0,
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    titleSpacing: automaticallyImplyLeading ? 0 : 18,
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
    actions: actions,
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
