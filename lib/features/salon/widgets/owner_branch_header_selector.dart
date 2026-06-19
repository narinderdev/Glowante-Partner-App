import 'package:flutter/material.dart';

const Color _selectorPrimaryText = Color(0xFF1C1917);
const Color _selectorSecondaryText = Color(0xFF78716C);
const Color _selectorAccent = Color(0xFFC19A6B);
const Color _selectorBorder = Color(0xFFE9DFD1);

class OwnerBranchHeaderSelectorOption<T> {
  const OwnerBranchHeaderSelectorOption({
    required this.value,
    required this.label,
    this.subtitle = '',
  });

  final T value;
  final String label;
  final String subtitle;
}

class OwnerBranchHeaderSelector<T> extends StatelessWidget {
  const OwnerBranchHeaderSelector({
    super.key,
    required this.label,
    required this.options,
    required this.selectedValue,
    required this.placeholder,
    required this.isInteractive,
    this.onSelected,
  });

  final String label;
  final List<OwnerBranchHeaderSelectorOption<T>> options;
  final T? selectedValue;
  final String placeholder;
  final bool isInteractive;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    final displayLabel = label.trim().isEmpty ? placeholder : label.trim();
    final selectedOption =
        options.cast<OwnerBranchHeaderSelectorOption<T>?>().firstWhere(
              (option) => option?.value == selectedValue,
              orElse: () => null,
            );
    final displaySubtitle = selectedOption?.subtitle.trim() ?? '';

    if (!isInteractive) {
      return _SelectorChrome(
        label: displayLabel,
        subtitle: displaySubtitle,
        isInteractive: false,
      );
    }

    return PopupMenuButton<T>(
      enabled: options.isNotEmpty,
      onSelected: onSelected,
      padding: EdgeInsets.zero,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      tooltip: '',
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _selectorBorder),
      ),
      itemBuilder: (context) {
        return options
            .map(
              (option) => PopupMenuItem<T>(
                value: option.value,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: _SelectorDropdownItem(
                  option: option,
                  isSelected: option.value == selectedValue,
                ),
              ),
            )
            .toList();
      },
      child: _SelectorChrome(
        label: displayLabel,
        subtitle: displaySubtitle,
        isInteractive: true,
      ),
    );
  }
}

class _SelectorChrome extends StatelessWidget {
  const _SelectorChrome({
    required this.label,
    required this.subtitle,
    required this.isInteractive,
  });

  final String label;
  final String subtitle;
  final bool isInteractive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _selectorBorder),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFF3E8D1),
              child: Icon(
                Icons.storefront_outlined,
                color: Color(0xFF8B6500),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _selectorPrimaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _selectorSecondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isInteractive)
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF8B6500),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectorDropdownItem<T> extends StatelessWidget {
  const _SelectorDropdownItem({
    required this.option,
    required this.isSelected,
  });

  final OwnerBranchHeaderSelectorOption<T> option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color:
            isSelected ? _selectorAccent.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _selectorAccent : _selectorBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _selectorAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: _selectorAccent,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _selectorPrimaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                if (option.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    option.subtitle.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _selectorSecondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
