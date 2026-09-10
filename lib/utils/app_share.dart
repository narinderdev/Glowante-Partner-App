import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'localization_helper.dart';

const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.glowante.client&pcampaignid=web_share';
const String _appStoreUrl =
    'https://apps.apple.com/in/app/glowante/id6749370773';

// Shared by both the owner and stylist Profile/More tabs. Only the current
// device's own platform link is included — an Android user sharing this
// isn't going to send an iPhone user a Play Store link they can't use (or
// vice versa), so whichever store they're actually on is what matters.
//
// Needs a BuildContext to supply sharePositionOrigin: on iPad,
// UIActivityViewController is a popover anchored to a screen rect, and
// share_plus throws without one — share(text) alone works fine on
// iPhone/Android but crashes specifically on iPad.
Future<void> shareGlowanteApp(BuildContext context) async {
  final storeUrl = defaultTargetPlatform == TargetPlatform.iOS
      ? _appStoreUrl
      : _playStoreUrl;
  final message =
      '${translateText("Skip the queue — book your salon's services via Glowante!")}\n\n$storeUrl';

  final box = context.findRenderObject() as RenderBox?;
  final sharePositionOrigin =
      box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

  await Share.share(message, sharePositionOrigin: sharePositionOrigin);
}
