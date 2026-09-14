import 'package:url_launcher/url_launcher.dart';

const String glowanteSupportEmail = 'support@glowante.com';

Future<bool> openGlowanteSupportEmail() {
  return launchUrl(Uri(scheme: 'mailto', path: glowanteSupportEmail));
}
