import 'package:flutter/widgets.dart';

/// Owns the [ChangeNotifier]s (typically [TextEditingController]s) that a
/// dialog's fields read, and disposes them when the dialog is unmounted.
///
/// `showDialog`'s future completes the moment the route is popped, which is
/// *before* the exit transition finishes and before the dialog's widgets leave
/// the tree. Disposing controllers in a `finally` right after that await tears
/// them down while the still-mounted `TextField`s keep reading them, which
/// throws "A TextEditingController was used after being disposed" and leaves
/// the popped subtree half-torn-down — the Overlay then trips
/// `'_dependents.isEmpty': is not true` and the whole app is replaced by the
/// red error screen.
///
/// Wrapping the dialog's content in this widget moves disposal to `dispose()`,
/// which the framework runs only after every descendant has been unmounted.
class DialogScopedResources extends StatefulWidget {
  const DialogScopedResources({
    super.key,
    required this.resources,
    required this.child,
  });

  final List<ChangeNotifier> resources;
  final Widget child;

  @override
  State<DialogScopedResources> createState() => _DialogScopedResourcesState();
}

class _DialogScopedResourcesState extends State<DialogScopedResources> {
  @override
  void dispose() {
    for (final resource in widget.resources) {
      resource.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
