import 'package:flutter/widgets.dart';

/// Global navigator key that allows services to perform navigation
/// without needing a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
