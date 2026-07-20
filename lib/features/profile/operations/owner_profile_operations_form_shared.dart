part of 'owner_profile_operations_screen.dart';

class _FormCard extends StatefulWidget {
  const _FormCard({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  State<_FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<_FormCard> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1EBE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3D5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8C774)),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.starColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Color(0xFF1C1917),
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                height: 38,
                child: IconButton(
                  onPressed: widget.onBack,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: const Color(0xFF78716C),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Flexible(
            child: RawScrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              trackVisibility: true,
              thickness: 4,
              radius: const Radius.circular(10),
              thumbColor: AppColors.starColor.withValues(alpha: 0.72),
              trackColor: const Color(0xFFFFF3D5),
              trackBorderColor: const Color(0xFFE8C774),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
