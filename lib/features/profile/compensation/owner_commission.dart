part of 'profile_compensation_screen.dart';

const int _commissionServicesPageSize = 8;

extension _OwnerCommissionUi on _ProfileCompensationScreenState {
  Widget _buildCommissionScreen() {
    if (_services.isEmpty) {
      return RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: () => _reloadContent(showLoader: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            _EmptyStateCard(
              title: context.t('No services found for this branch'),
              subtitle: context.t(
                'Commission setup needs active branch services and staff members.',
              ),
            ),
          ],
        ),
      );
    }

    final selectedService = _selectedService;
    final categoryFilterOptions = _commissionCategoryFilterOptions;
    final selectedCategoryFilter =
        categoryFilterOptions.contains(_commissionCategoryFilter)
            ? _commissionCategoryFilter
            : _commissionAllCategoriesValue;
    final filteredServices = _filteredServices;
    final servicePageCount = filteredServices.isEmpty
        ? 1
        : ((filteredServices.length - 1) / _commissionServicesPageSize)
                .floor() +
            1;
    final servicePage = filteredServices.isEmpty
        ? 0
        : math.min(_commissionServicesPage, servicePageCount - 1);
    final serviceStart = servicePage * _commissionServicesPageSize;
    final pageServices = filteredServices
        .skip(serviceStart)
        .take(_commissionServicesPageSize)
        .toList();

    return RefreshIndicator(
      color: AppColors.starColor,
      onRefresh: () => _reloadContent(showLoader: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4F1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE8DED6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CommissionTabButton(
                    label: context.t('Services'),
                    icon: Icons.content_cut_rounded,
                    isSelected: _commissionTab == _CommissionTab.services,
                    onTap: () =>
                        _setCommissionTabValue(_CommissionTab.services),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _CommissionTabButton(
                    label: context.t('Staff Overrides'),
                    icon: Icons.groups_2_rounded,
                    isSelected: _commissionTab == _CommissionTab.overrides,
                    onTap: () =>
                        _setCommissionTabValue(_CommissionTab.overrides),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('Staff override rules'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t(
              'Custom service commission rates assigned to individual staff.',
            ),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _serviceSearchController,
                  // maxLength: 60,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: _commissionTab == _CommissionTab.services
                        ? context.t('Search services')
                        : context.t('Search staff or service'),
                    hintStyle:
                        const TextStyle(fontSize: 12, color: Color(0xFF8A8178)),
                    prefixIcon: const Icon(Icons.search, size: 17),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: Color(0xFFE8DED6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(color: Color(0xFFE8DED6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(9),
                      borderSide: const BorderSide(
                        color: AppColors.starColor,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
              if (_commissionTab == _CommissionTab.services) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 142,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCategoryFilter,
                        isExpanded: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF8A8178),
                        ),
                        borderRadius: BorderRadius.circular(10),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A2622),
                        ),
                        items: categoryFilterOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  context.t(
                                    _commissionCategoryFilterLabel(value),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          _setCommissionCategoryFilter(value);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (_commissionTab == _CommissionTab.services) ...[
            filteredServices.isEmpty
                ? SizedBox(
                    height: 86,
                    child: _NoCommissionMatchesCard(
                      title: context.t('No matching services'),
                      subtitle: context.t(
                        'Try a different service name or clear the search.',
                      ),
                    ),
                  )
                : _ServiceCommissionTable(
                    services: pageServices,
                    selectedServiceId: selectedService?.id,
                    overrides: _staffOverrides,
                    onSelect: _selectCommissionService,
                  ),
            if (filteredServices.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CommissionPaginationBar(
                start: serviceStart + 1,
                end: math.min(
                  serviceStart + pageServices.length,
                  filteredServices.length,
                ),
                total: filteredServices.length,
                currentPage: servicePage + 1,
                totalPages: servicePageCount,
                onPrevious: servicePage <= 0
                    ? null
                    : () => _setCommissionServicesPage(servicePage - 1),
                onNext: servicePage >= servicePageCount - 1
                    ? null
                    : () => _setCommissionServicesPage(servicePage + 1),
              ),
            ],
            const SizedBox(height: 18),
            if (selectedService == null)
              _EmptyStateCard(
                title: context.t('Select a service'),
                subtitle: context.t(
                  'Choose a service to configure staff-specific commission overrides.',
                ),
              )
            else
              _SelectedServiceOverridesCard(
                service: selectedService,
                overrides: _selectedServiceOverrides,
                teamMembers: _teamMembers,
                isActionInProgress: _isActionInProgress,
                onAdd: _openAddOverrideDialog,
                onViewAll: () =>
                    _setCommissionTabValue(_CommissionTab.overrides),
                onEdit: _openEditOverrideDialog,
                onDelete: _deleteOverride,
              ),
          ] else ...[
            const SizedBox(height: 8),
            _AllStaffOverridesCard(
              overrides: _filteredStaffOverrides,
              services: _services,
              teamMembers: _teamMembers,
              isActionInProgress: _isActionInProgress,
              onAdd: _openAddOverrideDialog,
              onEdit: _openEditOverrideDialog,
              onDelete: _deleteOverride,
            ),
          ],
        ],
      ),
    );
  }
}

class _CommissionTabButton extends StatelessWidget {
  const _CommissionTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.starColor : Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF5F574F),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF5F574F),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoCommissionMatchesCard extends StatelessWidget {
  const _NoCommissionMatchesCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCommissionTable extends StatelessWidget {
  const _ServiceCommissionTable({
    required this.services,
    required this.selectedServiceId,
    required this.overrides,
    required this.onSelect,
  });

  final List<BranchServiceSummary> services;
  final int? selectedServiceId;
  final List<StaffCommissionOverride> overrides;
  final ValueChanged<int> onSelect;

  int _overrideCount(int serviceId) {
    return overrides
        .where((override) => override.serviceId == serviceId)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: _CommissionHorizontalScrollHint(
          child: SizedBox(
            width: 720,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: const Color(0xFFF7F4F1),
                  child: Row(
                    children: [
                      _CommissionTableHeaderCell(
                        flex: 3,
                        label: context.t('Service'),
                      ),
                      _CommissionTableHeaderCell(
                        flex: 2,
                        label: context.t('Category'),
                      ),
                      _CommissionTableHeaderCell(
                        flex: 2,
                        label: context.t('Default commission'),
                      ),
                      _CommissionTableHeaderCell(
                        flex: 1,
                        label: context.t('Overrides'),
                      ),
                      _CommissionTableHeaderCell(
                        flex: 1,
                        label: context.t('Status'),
                      ),
                    ],
                  ),
                ),
                ...services.map((service) {
                  final isSelected = service.id == selectedServiceId;
                  return _ServiceCommissionTableRow(
                    service: service,
                    overrideCount: _overrideCount(service.id),
                    isSelected: isSelected,
                    onTap: () => onSelect(service.id),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommissionHorizontalScrollHint extends StatefulWidget {
  const _CommissionHorizontalScrollHint({required this.child});

  final Widget child;

  @override
  State<_CommissionHorizontalScrollHint> createState() =>
      _CommissionHorizontalScrollHintState();
}

class _CommissionHorizontalScrollHintState
    extends State<_CommissionHorizontalScrollHint> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawScrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      thickness: 4,
      radius: const Radius.circular(10),
      thumbColor: AppColors.starColor.withValues(alpha: 0.72),
      trackColor: const Color(0xFFFFF3D5),
      trackBorderColor: const Color(0xFFE8C774),
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 12),
        child: widget.child,
      ),
    );
  }
}

class _CommissionPaginationBar extends StatelessWidget {
  const _CommissionPaginationBar({
    required this.start,
    required this.end,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  final int start;
  final int end;
  final int total;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$start-$end ${context.t('of')} $total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8A8178),
            ),
          ),
        ),
        Text(
          '$currentPage / $totalPages',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B625A),
          ),
        ),
        const SizedBox(width: 8),
        _CommissionPageButton(
          label: context.t('Previous'),
          onTap: onPrevious,
        ),
        const SizedBox(width: 6),
        _CommissionPageButton(
          label: context.t('Next'),
          onTap: onNext,
        ),
      ],
    );
  }
}

class _CommissionPageButton extends StatelessWidget {
  const _CommissionPageButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF3F0ED),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? const Color(0xFFD4B985) : const Color(0xFFE1D6CB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: enabled ? AppColors.starColor : const Color(0xFFB8AEA5),
          ),
        ),
      ),
    );
  }
}

class _CommissionTableHeaderCell extends StatelessWidget {
  const _CommissionTableHeaderCell({
    required this.flex,
    required this.label,
  });

  final int flex;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: Color(0xFF7A7169),
        ),
      ),
    );
  }
}

class _ServiceCommissionTableRow extends StatelessWidget {
  const _ServiceCommissionTableRow({
    required this.service,
    required this.overrideCount,
    required this.isSelected,
    required this.onTap,
  });

  final BranchServiceSummary service;
  final int overrideCount;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFFF3EEE8) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFE8DED6)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFFFFEFF2),
                      child: Text(
                        _commissionInitials(service.name),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE11D48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                          // const SizedBox(height: 3),
                          // Text(
                          //   service.description.isEmpty
                          //       ? 'ID ${service.id}'
                          //       : service.description,
                          //   maxLines: 1,
                          //   overflow: TextOverflow.ellipsis,
                          //   style: const TextStyle(
                          //     fontSize: 10,
                          //     color: Color(0xFF8A8178),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  service.categoryName.isEmpty
                      ? context.t('Uncategorized')
                      : service.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CommissionValueBadge(
                    label: _serviceDefaultCommissionLabel(service),
                    muted: !service.commissionEnabled,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '$overrideCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.starColor,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _CommissionStatusPill(active: service.isActive),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedServiceOverridesCard extends StatelessWidget {
  const _SelectedServiceOverridesCard({
    required this.service,
    required this.overrides,
    required this.teamMembers,
    required this.isActionInProgress,
    required this.onAdd,
    required this.onViewAll,
    required this.onEdit,
    required this.onDelete,
  });

  final BranchServiceSummary service;
  final List<StaffCommissionOverride> overrides;
  final List<ProfileTeamMember> teamMembers;
  final bool isActionInProgress;
  final VoidCallback onAdd;
  final VoidCallback onViewAll;
  final ValueChanged<StaffCommissionOverride> onEdit;
  final ValueChanged<String> onDelete;

  String _roleFor(StaffCommissionOverride override) {
    for (final member in teamMembers) {
      if (member.id == override.staffId) {
        return member.role.trim().isEmpty ? 'Team Member' : member.role;
      }
    }
    return 'Team Member';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SelectedCommissionServiceHeader(service: service),
          const SizedBox(height: 12),
          _DefaultCommissionSummaryCard(service: service),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8DED6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            context.t('Staff overrides'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1C1917),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CommissionCountPill(label: '${overrides.length}'),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: onViewAll,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.starColor,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(context.t('View all')),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (overrides.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCFAF8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE8DED6)),
                    ),
                    child: Text(
                      context.t('No overrides set for this service.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  )
                else
                  ...overrides.map(
                    (override) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StaffOverrideRowCard(
                        staffOverride: override,
                        service: service,
                        staffRole: _roleFor(override),
                        isActionInProgress: isActionInProgress,
                        showService: false,
                        onEdit: () => onEdit(override),
                        onDelete: () => onDelete(override.id),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isActionInProgress ? null : onAdd,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.starColor,
                      side: const BorderSide(color: Color(0xFFD4B985)),
                      backgroundColor: const Color(0xFFFFFBF3),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      isActionInProgress
                          ? context.t('Saving...')
                          : context.t('Add staff override'),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t(
                    'Override rates take priority over the default rate during payroll calculation.',
                  ),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Color(0xFF9CA3AF),
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

class _SelectedCommissionServiceHeader extends StatelessWidget {
  const _SelectedCommissionServiceHeader({required this.service});

  final BranchServiceSummary service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFEFF2),
            child: Text(
              _commissionInitials(service.name),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE11D48),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  service.categoryName.isEmpty
                      ? context.t('Uncategorized')
                      : service.categoryName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          _CommissionStatusPill(active: service.isActive),
        ],
      ),
    );
  }
}

class _DefaultCommissionSummaryCard extends StatefulWidget {
  const _DefaultCommissionSummaryCard({required this.service});

  final BranchServiceSummary service;

  @override
  State<_DefaultCommissionSummaryCard> createState() =>
      _DefaultCommissionSummaryCardState();
}

class _DefaultCommissionSummaryCardState
    extends State<_DefaultCommissionSummaryCard> {
  late String _selectedRuleType;

  @override
  void initState() {
    super.initState();
    _selectedRuleType = _initialRuleType;
  }

  @override
  void didUpdateWidget(covariant _DefaultCommissionSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service.id != widget.service.id ||
        oldWidget.service.commissionType != widget.service.commissionType) {
      _selectedRuleType = _initialRuleType;
    }
  }

  String get _initialRuleType => _serviceDefaultIsPercentage(widget.service)
      ? CommissionRuleTypes.percentage
      : CommissionRuleTypes.fixed;

  void _selectRuleType(String value) {
    setState(() => _selectedRuleType = value);
  }

  String get _rateValue {
    if (_selectedRuleType == CommissionRuleTypes.fixed) {
      final fixedAmountMinor = widget.service.commissionFixedAmountMinor ??
          widget.service.commissionMaxAmountMinor;
      final rupees = minorAmountToRupees(fixedAmountMinor) ?? 0;
      return _formatOverrideNumber(rupees);
    }
    return _formatOverrideNumber(widget.service.commissionPercentage ?? 0);
  }

  String get _rateSymbol =>
      _selectedRuleType == CommissionRuleTypes.fixed ? '₹' : '%';

  @override
  Widget build(BuildContext context) {
    final enabled = widget.service.commissionEnabled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('Default commission'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1C1917),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('Applies to all staff unless overridden.'),
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 12),
          if (!enabled)
            _CommissionValueBadge(
                label: context.t('No commission'), muted: true)
          else ...[
            _CommissionDialogLabel(context.t('Type')),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _ReadOnlyCommissionTypeChip(
                  label: context.t('Percentage (%)'),
                  selected: _selectedRuleType == CommissionRuleTypes.percentage,
                  onTap: () => _selectRuleType(CommissionRuleTypes.percentage),
                ),
                _ReadOnlyCommissionTypeChip(
                  label: context.t('Fixed Amount (Rs.)'),
                  selected: _selectedRuleType == CommissionRuleTypes.fixed,
                  onTap: () => _selectRuleType(CommissionRuleTypes.fixed),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CommissionDialogLabel(context.t('Rate')),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFCFAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE8DED6)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _rateValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1917),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _rateSymbol,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8A8178),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE6C978)),
            ),
            child: Text(
              enabled
                  ? context.t(
                      'Staff overrides take priority over this default rate.',
                    )
                  : context.t(
                      'No default commission is configured for this service.',
                    ),
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: Color(0xFF8A5A00),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyCommissionTypeChip extends StatelessWidget {
  const _ReadOnlyCommissionTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.starColor : const Color(0xFFB8AEA5),
                width: selected ? 2.4 : 1.6,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.starColor,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color:
                  selected ? const Color(0xFF1C1917) : const Color(0xFF6B625A),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllStaffOverridesCard extends StatelessWidget {
  const _AllStaffOverridesCard({
    required this.overrides,
    required this.services,
    required this.teamMembers,
    required this.isActionInProgress,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<StaffCommissionOverride> overrides;
  final List<BranchServiceSummary> services;
  final List<ProfileTeamMember> teamMembers;
  final bool isActionInProgress;
  final VoidCallback onAdd;
  final ValueChanged<StaffCommissionOverride> onEdit;
  final ValueChanged<String> onDelete;

  BranchServiceSummary? _serviceFor(StaffCommissionOverride override) {
    for (final service in services) {
      if (service.id == override.serviceId) {
        return service;
      }
    }
    return null;
  }

  String _roleFor(StaffCommissionOverride override) {
    for (final member in teamMembers) {
      if (member.id == override.staffId) {
        return member.role.trim().isEmpty ? 'Team Member' : member.role;
      }
    }
    return 'Team Member';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isActionInProgress ? null : onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(132, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  isActionInProgress
                      ? context.t('Saving...')
                      : context.t('Add override'),
                ),
              ),
            ),
          ),
          if (overrides.isEmpty)
            Padding(
              padding: const EdgeInsets.all(14),
              child: _EmptyStateCard(
                title: context.t('No staff overrides found'),
                subtitle: context.t(
                  'Add staff-specific commission rates for any service.',
                ),
              ),
            )
          else
            _CommissionHorizontalScrollHint(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _StaffOverrideTableHeader(),
                    ...overrides.map((override) {
                      final service = _serviceFor(override);
                      return _StaffOverrideTableRow(
                        staffOverride: override,
                        service: service,
                        staffRole: _roleFor(override),
                        isActionInProgress: isActionInProgress,
                        onEdit: () => onEdit(override),
                        onDelete: () => onDelete(override.id),
                      );
                    }),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Text(
              '${overrides.length} ${context.t(overrides.length == 1 ? 'override' : 'overrides')}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffOverrideTableHeader extends StatelessWidget {
  const _StaffOverrideTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF9F8),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8DED6)),
        ),
      ),
      child: Row(
        children: [
          _StaffOverrideTableCell(
            width: 250,
            isHeader: true,
            child: Text(context.t('STAFF')),
          ),
          _StaffOverrideTableCell(
            width: 210,
            isHeader: true,
            child: Text(context.t('SERVICE')),
          ),
          _StaffOverrideTableCell(
            width: 150,
            isHeader: true,
            child: Text(context.t('CATEGORY')),
          ),
          _StaffOverrideTableCell(
            width: 110,
            isHeader: true,
            child: Text(context.t('CUSTOM RATE')),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _StaffOverrideTableRow extends StatelessWidget {
  const _StaffOverrideTableRow({
    required this.staffOverride,
    required this.service,
    required this.staffRole,
    required this.isActionInProgress,
    required this.onEdit,
    required this.onDelete,
  });

  final StaffCommissionOverride staffOverride;
  final BranchServiceSummary? service;
  final String staffRole;
  final bool isActionInProgress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = _staffOverrideAmount(staffOverride);
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEFE7DF)),
        ),
      ),
      child: Row(
        children: [
          _StaffOverrideTableCell(
            width: 250,
            child: Row(
              children: [
                _CommissionInitialsAvatar(name: staffOverride.staffName),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffOverride.staffName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1917),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        staffRole,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _StaffOverrideTableCell(
            width: 210,
            child: Text(
              service?.name ?? context.t('Unknown service'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF374151),
              ),
            ),
          ),
          _StaffOverrideTableCell(
            width: 150,
            child: Text(
              service?.categoryName.trim().isNotEmpty == true
                  ? service!.categoryName
                  : context.t('Uncategorized'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          _StaffOverrideTableCell(
            width: 110,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _CommissionValueBadge(label: amount),
            ),
          ),
          SizedBox(
            width: 40,
            child: _StaffOverrideActionsButton(
              isActionInProgress: isActionInProgress,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffOverrideTableCell extends StatelessWidget {
  const _StaffOverrideTableCell({
    required this.width,
    required this.child,
    this.isHeader = false,
  });

  final double width;
  final Widget child;
  final bool isHeader;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DefaultTextStyle(
          style: TextStyle(
            fontSize: isHeader ? 11 : 13,
            fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
            letterSpacing: isHeader ? 0.4 : 0,
            color: isHeader ? const Color(0xFF6B7280) : const Color(0xFF1C1917),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CommissionCountPill extends StatelessWidget {
  const _CommissionCountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6C978)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.starColor,
        ),
      ),
    );
  }
}

class _CommissionValueBadge extends StatelessWidget {
  const _CommissionValueBadge({
    required this.label,
    this.muted = false,
  });

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF3F0ED) : const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: muted ? const Color(0xFFE1D6CB) : const Color(0xFFE6C978),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: muted ? const Color(0xFF8A8178) : AppColors.starColor,
        ),
      ),
    );
  }
}

class _CommissionStatusPill extends StatelessWidget {
  const _CommissionStatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE9F9EF) : const Color(0xFFF3F0ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.t(active ? 'Active' : 'Inactive'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: active ? const Color(0xFF16803A) : const Color(0xFF8A8178),
        ),
      ),
    );
  }
}

class _StaffOverrideRowCard extends StatelessWidget {
  const _StaffOverrideRowCard({
    required this.staffOverride,
    required this.service,
    required this.staffRole,
    required this.isActionInProgress,
    required this.showService,
    required this.onEdit,
    required this.onDelete,
  });

  final StaffCommissionOverride staffOverride;
  final BranchServiceSummary? service;
  final String staffRole;
  final bool isActionInProgress;
  final bool showService;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = _staffOverrideAmount(staffOverride);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0E7DF)),
      ),
      child: Row(
        children: [
          _CommissionInitialsAvatar(name: staffOverride.staffName),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staffOverride.staffName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  showService
                      ? (service?.name ?? context.t('Unknown service'))
                      : staffRole,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                if (showService) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${context.t('Effective from')} ${DateFormat('dd MMM yyyy').format(staffOverride.effectiveFrom)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: _CommissionValueBadge(label: amount),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 32,
            height: 32,
            child: _StaffOverrideActionsButton(
              isActionInProgress: isActionInProgress,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionInitialsAvatar extends StatelessWidget {
  const _CommissionInitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFF0E6D6),
      child: Text(
        _commissionInitials(name),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.starColor,
        ),
      ),
    );
  }
}

class _StaffOverrideActionsButton extends StatelessWidget {
  const _StaffOverrideActionsButton({
    required this.isActionInProgress,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isActionInProgress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isActionInProgress,
      tooltip: context.t('Actions'),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      icon: const Icon(
        Icons.more_vert_rounded,
        color: Color(0xFF8A8178),
        size: 20,
      ),
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.starColor,
              ),
              const SizedBox(width: 8),
              Text(context.t('Edit')),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.red,
              ),
              const SizedBox(width: 8),
              Text(
                context.t('Delete'),
                style: const TextStyle(color: AppColors.red),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _staffOverrideAmount(StaffCommissionOverride override) {
  return override.ruleType == CommissionRuleTypes.percentage
      ? '${_formatOverrideNumber(override.value)}%'
      : _formatCurrency(override.value.round());
}

String _formatOverrideNumber(num value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

bool _serviceDefaultIsPercentage(BranchServiceSummary service) {
  return (service.commissionType ?? '').toLowerCase() !=
      CommissionRuleTypes.fixed;
}

String _serviceDefaultCommissionLabel(BranchServiceSummary service) {
  if (!service.commissionEnabled) {
    return 'No commission';
  }
  if (_serviceDefaultIsPercentage(service)) {
    return '${_formatOverrideNumber(service.commissionPercentage ?? 0)}%';
  }
  return _formatCurrency(
    service.commissionFixedAmountMinor ?? service.commissionMaxAmountMinor ?? 0,
  );
}

String _commissionInitials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return 'ST';
  }
  final first = parts.first.characters.first.toUpperCase();
  final second =
      parts.length > 1 ? parts.last.characters.first.toUpperCase() : '';
  return '$first$second';
}

String _commissionRateLabel(
  StaffCommissionOverride? override, {
  String fallback = 'No override',
}) {
  if (override == null) {
    return fallback;
  }
  return override.ruleType == CommissionRuleTypes.percentage
      ? '${_formatOverrideNumber(override.value)}%'
      : _formatCurrency(override.value.round());
}

class _AddOverrideDialog extends StatefulWidget {
  const _AddOverrideDialog({
    required this.title,
    required this.submitLabel,
    required this.serviceId,
    required this.services,
    required this.staff,
    required this.existingOverrides,
    required this.onSubmit,
    this.initialOverride,
  });

  final String title;
  final String submitLabel;
  final int serviceId;
  final List<BranchServiceSummary> services;
  final List<ProfileTeamMember> staff;
  final List<StaffCommissionOverride> existingOverrides;
  final Future<void> Function(
    int serviceId,
    List<StaffCommissionOverride> overrides,
  ) onSubmit;
  final StaffCommissionOverride? initialOverride;

  @override
  State<_AddOverrideDialog> createState() => _AddOverrideDialogState();
}

class _AddOverrideDialogState extends State<_AddOverrideDialog> {
  final _formKey = GlobalKey<FormState>();
  final Set<int> _selectedStaffIds = <int>{};
  final TextEditingController _staffSearchController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  late int _selectedServiceId;
  String _ruleType = CommissionRuleTypes.percentage;
  DateTime _effectiveFrom = DateTime.now();
  bool _isSaving = false;
  bool get _isEdit => widget.initialOverride != null;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.serviceId;
    final initial = widget.initialOverride;
    if (initial != null) {
      _selectedStaffIds.add(initial.staffId);
      _ruleType = initial.ruleType;
      _effectiveFrom = initial.effectiveFrom;
      _valueController.text = initial.ruleType == CommissionRuleTypes.fixed
          ? _formatOverrideNumber(minorAmountToRupees(initial.value) ?? 0)
          : _formatOverrideNumber(initial.value);
      _notesController.text = initial.notes;
    } else {
      _ruleType = _defaultRuleTypeForService(_selectedService);
      _valueController.text = _defaultRateTextForSelectedService();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    _staffSearchController.dispose();
    _valueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _validateIfNeeded() {
    if (_autoValidateMode != AutovalidateMode.disabled) {
      _formKey.currentState?.validate();
    }
  }

  bool _shouldValidateRateImmediately(String value) {
    if (_ruleType != CommissionRuleTypes.percentage) {
      return false;
    }
    final parsed = double.tryParse(value.trim());
    return parsed != null && parsed > 100;
  }

  void _handleRateChanged(String value) {
    final shouldValidate = _shouldValidateRateImmediately(value);
    setState(() {
      if (shouldValidate) {
        _autoValidateMode = AutovalidateMode.onUserInteraction;
      }
    });
    if (shouldValidate) {
      _formKey.currentState?.validate();
    } else {
      _validateIfNeeded();
    }
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _autoValidateMode = AutovalidateMode.onUserInteraction;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final parsed = double.parse(_valueController.text.trim());
    final serviceId = _selectedServiceId;
    final ruleType = _ruleType;

    final overrides = widget.staff
        .where((member) => _selectedStaffIds.contains(member.id))
        .map(
          (member) => StaffCommissionOverride(
            id: _isEdit
                ? widget.initialOverride!.id
                : '${serviceId}_${member.id}_${DateTime.now().millisecondsSinceEpoch}',
            serviceId: serviceId,
            staffId: member.id,
            staffName: member.name,
            ruleType: ruleType,
            value: ruleType == CommissionRuleTypes.fixed
                ? rupeesToMinorAmount(parsed).toDouble()
                : parsed,
            effectiveFrom: _effectiveFrom,
            notes: _notesController.text.trim(),
          ),
        )
        .toList();

    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(serviceId, overrides);
      if (mounted) {
        _closeDialog();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  BranchServiceSummary? get _selectedService {
    for (final service in widget.services) {
      if (service.id == _selectedServiceId) {
        return service;
      }
    }
    return widget.services.isEmpty ? null : widget.services.first;
  }

  String _defaultRuleTypeForService(BranchServiceSummary? service) {
    if (service == null) {
      return CommissionRuleTypes.percentage;
    }
    return _serviceDefaultIsPercentage(service)
        ? CommissionRuleTypes.percentage
        : CommissionRuleTypes.fixed;
  }

  String _defaultRateTextForSelectedService() {
    final service = _selectedService;
    if (service == null) {
      return '';
    }
    if (_ruleType == CommissionRuleTypes.fixed) {
      final fixedAmountMinor = service.commissionFixedAmountMinor ??
          service.commissionMaxAmountMinor;
      return _formatOverrideNumber(minorAmountToRupees(fixedAmountMinor) ?? 0);
    }
    return _formatOverrideNumber(service.commissionPercentage ?? 0);
  }

  void _syncRateFromSelectedService({bool resetRuleType = false}) {
    final service = _selectedService;
    if (resetRuleType) {
      _ruleType = _defaultRuleTypeForService(service);
    }
    _valueController.text = _defaultRateTextForSelectedService();
  }

  List<TextInputFormatter> get _rateInputFormatters {
    if (_ruleType == CommissionRuleTypes.percentage) {
      return <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ];
    }
    return <TextInputFormatter>[
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if (RegExp(r'^\d{0,6}(\.\d{0,2})?$').hasMatch(text)) {
          return newValue;
        }
        return oldValue;
      }),
      LengthLimitingTextInputFormatter(9),
    ];
  }

  bool get _hasValidRate {
    final text = _valueController.text.trim();
    if (text.isEmpty) {
      return false;
    }
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return false;
    }
    if (_ruleType == CommissionRuleTypes.percentage) {
      return text.length <= 3 && parsed <= 100;
    }
    final priceRupees = minorAmountToRupees(_selectedService?.priceMinor);
    return priceRupees == null || parsed <= priceRupees;
  }

  bool get _canSubmit =>
      !_isSaving &&
      _selectedService != null &&
      _selectedStaffIds.isNotEmpty &&
      _hasValidRate;

  List<ProfileTeamMember> get _filteredStaff {
    final query = _staffSearchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.staff;
    }
    return widget.staff.where((member) {
      final haystack =
          '${member.name} ${member.role} ${member.phoneNumber} ${member.id}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  StaffCommissionOverride? _existingOverrideFor(int staffId) {
    for (final override in widget.existingOverrides) {
      if (override.serviceId == _selectedServiceId &&
          override.staffId == staffId &&
          override.id != widget.initialOverride?.id) {
        return override;
      }
    }
    return null;
  }

  InputDecoration _dialogInputDecoration({
    String? hintText,
    Widget? prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9A9189)),
      prefixIcon: prefixIcon,
      suffix: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE1D6CB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE1D6CB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.starColor, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.red, width: 1.2),
      ),
      errorStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.red,
      ),
      errorMaxLines: 2,
    );
  }

  Future<void> _pickEffectiveDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom,
      firstDate: DateTime(2022),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _effectiveFrom = picked);
    }
  }

  void _closeDialog() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context);
  }

  Widget _buildDialogActionRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_selectedStaffIds.length} ${context.t(_selectedStaffIds.length == 1 ? 'staff selected' : 'staff selected')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _closeDialog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.starColor,
                  side: const BorderSide(color: Color(0xFFD4B985)),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: Text(context.t('Cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.starColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8D2CA),
                  disabledForegroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: _isSaving
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(context.t('Saving...'))),
                        ],
                      )
                    : Text(
                        widget.submitLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  ProfileTeamMember? get _selectedStaffForEdit {
    final staffId = widget.initialOverride?.staffId;
    if (staffId == null) {
      return null;
    }
    for (final member in widget.staff) {
      if (member.id == staffId) {
        return member;
      }
    }
    return null;
  }

  String _rateValidationMessage(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return translateText('Enter a valid override value');
    }
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return translateText('Enter a valid override value');
    }
    if (_ruleType == CommissionRuleTypes.percentage) {
      if (text.length > 3 || parsed > 100) {
        return translateText('Percentage cannot be greater than 100');
      }
    } else {
      final selectedService = _selectedService;
      final priceRupees = minorAmountToRupees(selectedService?.priceMinor);
      if (priceRupees != null && parsed > priceRupees) {
        return translateText(
          'Fixed amount cannot be greater than Rs. ${_formatOverrideNumber(priceRupees)}',
        );
      }
    }
    return '';
  }

  Widget _buildRateInput() {
    return TextFormField(
      controller: _valueController,
      enabled: !_isSaving,
      autofocus: false,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _rateInputFormatters,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      decoration: _dialogInputDecoration(
        suffix: Text(
          _ruleType == CommissionRuleTypes.percentage ? '%' : '₹',
          style: const TextStyle(
            color: Color(0xFF8A8178),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      validator: (value) {
        final message = _rateValidationMessage(value);
        return message.isEmpty ? null : message;
      },
      onChanged: _isSaving ? null : _handleRateChanged,
    );
  }

  Widget _buildEffectiveDateInput() {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _isSaving ? null : _pickEffectiveDate,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1D6CB)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(_effectiveFrom),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1917),
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: AppColors.starColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditOverrideBody(
    BuildContext context,
    BranchServiceSummary? selectedService,
  ) {
    final staff = _selectedStaffForEdit;
    final override = widget.initialOverride;
    final staffName = staff?.name ?? override?.staffName ?? context.t('Staff');
    final staffRole = staff?.role.trim().isNotEmpty == true
        ? staff!.role
        : context.t('Team Member');

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        autovalidateMode: _autoValidateMode,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F5F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE8DED6)),
              ),
              child: Row(
                children: [
                  _CommissionInitialsAvatar(name: staffName),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staffName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1C1917),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          staffRole,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8178),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 82,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          context.t('Service'),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFFB0A8A1),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          selectedService?.name ?? context.t('Unknown service'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1C1917),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CommissionDialogLabel(context.t('Commission type')),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _CommissionRuleRadio(
                  label: context.t('Percentage (%)'),
                  value: CommissionRuleTypes.percentage,
                  groupValue: _ruleType,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _ruleType = value;
                            _syncRateFromSelectedService();
                          });
                          _validateIfNeeded();
                        },
                ),
                _CommissionRuleRadio(
                  label: context.t('Fixed Amount (Rs.)'),
                  value: CommissionRuleTypes.fixed,
                  groupValue: _ruleType,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _ruleType = value;
                            _syncRateFromSelectedService();
                          });
                          _validateIfNeeded();
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommissionDialogLabel(context.t('Rate *')),
                      _buildRateInput(),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CommissionDialogLabel(context.t('Effective from')),
                      _buildEffectiveDateInput(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CommissionDialogLabel(context.t('Notes')),
            TextFormField(
              controller: _notesController,
              enabled: !_isSaving,
              autofocus: false,
              maxLines: 1,
              style: const TextStyle(fontSize: 12),
              decoration:
                  _dialogInputDecoration(hintText: context.t('Optional')),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 96,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _closeDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4B5563),
                      side: const BorderSide(color: Color(0xFFE1D6CB)),
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(context.t('Cancel')),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 130,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.starColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD8D2CA),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      _isSaving ? context.t('Saving...') : widget.submitLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedService = _selectedService;
    final filteredStaff = _filteredStaff;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      backgroundColor: const Color(0xFFFFFBF7),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      titlePadding: const EdgeInsets.fromLTRB(18, 18, 12, 0),
      contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1C1917),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEdit
                      ? context.t(
                          'Update the custom commission rate for this staff member.',
                        )
                      : context.t(
                          'Set a custom commission rate for one or more staff members.',
                        ),
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: _isSaving ? null : _closeDialog,
            icon: const Icon(Icons.close_rounded, color: Color(0xFF6B625A)),
          ),
        ],
      ),
      content: SizedBox(
        width: _isEdit ? 360 : 520,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: _isEdit
              ? _buildEditOverrideBody(context, selectedService)
              : SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autoValidateMode,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedService != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F5F2),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFE8DED6)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFFFFEFF2),
                                  child: Text(
                                    _commissionInitials(selectedService.name),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFE11D48),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        selectedService.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF1C1917),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        selectedService.categoryName.isEmpty
                                            ? context.t('Service')
                                            : selectedService.categoryName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _CommissionValueBadge(
                                  label:
                                      '${context.t('Default')} ${_serviceDefaultCommissionLabel(selectedService)}',
                                  muted: !selectedService.commissionEnabled,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _CommissionDialogLabel(context.t('Service')),
                        DropdownButtonFormField<int>(
                          initialValue: _selectedServiceId,
                          isExpanded: true,
                          decoration: _dialogInputDecoration(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 18),
                          items: widget.services
                              .map(
                                (service) => DropdownMenuItem<int>(
                                  value: service.id,
                                  child: Text(
                                    service.categoryName.isEmpty
                                        ? service.name
                                        : '${service.name} - ${service.categoryName}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving || _isEdit
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }
                                  setState(() {
                                    _selectedServiceId = value;
                                    _syncRateFromSelectedService(
                                        resetRuleType: true);
                                  });
                                  _validateIfNeeded();
                                },
                        ),
                        const SizedBox(height: 16),
                        _CommissionDialogLabel(
                          _isEdit
                              ? context.t('Selected staff')
                              : context.t('1. Select staff members'),
                        ),
                        if (!_isEdit) ...[
                          TextField(
                            controller: _staffSearchController,
                            enabled: !_isSaving,
                            autofocus: false,
                            style: const TextStyle(fontSize: 12),
                            decoration: _dialogInputDecoration(
                              hintText:
                                  context.t('Search by name, role, or ID'),
                              prefixIcon: const Icon(Icons.search, size: 17),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                        ],
                        FormField<Set<int>>(
                          initialValue: _selectedStaffIds.toSet(),
                          validator: (_) => _selectedStaffIds.isEmpty
                              ? translateText(
                                  'Select at least one staff member')
                              : null,
                          builder: (field) {
                            final visibleStaffIds = filteredStaff
                                .map((member) => member.id)
                                .toSet();
                            final selectedVisibleCount = visibleStaffIds
                                .where(_selectedStaffIds.contains)
                                .length;
                            final bool? allVisibleSelected =
                                selectedVisibleCount == 0
                                    ? false
                                    : selectedVisibleCount ==
                                            visibleStaffIds.length
                                        ? true
                                        : null;
                            final tableHeight = math.min(
                              232.0,
                              38.0 + (filteredStaff.length * 58.0),
                            );
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: filteredStaff.isEmpty
                                      ? null
                                      : tableHeight,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: const Color(0xFFE8DED6)),
                                  ),
                                  child: filteredStaff.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Text(
                                            context.t('No staff found'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF6B7280),
                                            ),
                                          ),
                                        )
                                      : SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: SizedBox(
                                            width: 760,
                                            height: tableHeight,
                                            child: Column(
                                              children: [
                                                _StaffPickerHeaderRow(
                                                  value: allVisibleSelected,
                                                  enabled:
                                                      !_isSaving && !_isEdit,
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value ?? false) {
                                                        _selectedStaffIds.addAll(
                                                            visibleStaffIds);
                                                      } else {
                                                        _selectedStaffIds
                                                            .removeAll(
                                                          visibleStaffIds,
                                                        );
                                                      }
                                                    });
                                                    field.didChange(
                                                      _selectedStaffIds.toSet(),
                                                    );
                                                    _validateIfNeeded();
                                                  },
                                                ),
                                                Expanded(
                                                  child: ListView.separated(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        filteredStaff.length,
                                                    separatorBuilder: (_, __) =>
                                                        const Divider(
                                                      height: 1,
                                                      color: Color(0xFFE8DED6),
                                                    ),
                                                    itemBuilder:
                                                        (context, index) {
                                                      final member =
                                                          filteredStaff[index];
                                                      final isSelected =
                                                          _selectedStaffIds
                                                              .contains(
                                                                  member.id);
                                                      final existing =
                                                          _existingOverrideFor(
                                                        member.id,
                                                      );
                                                      return _StaffPickerRow(
                                                        member: member,
                                                        selected: isSelected,
                                                        enabled: !_isSaving &&
                                                            !_isEdit,
                                                        currentRate:
                                                            _commissionRateLabel(
                                                          existing,
                                                          fallback:
                                                              selectedService ==
                                                                      null
                                                                  ? 'No override'
                                                                  : _serviceDefaultCommissionLabel(
                                                                      selectedService,
                                                                    ),
                                                        ),
                                                        onChanged: (value) {
                                                          setState(() {
                                                            if (value) {
                                                              _selectedStaffIds
                                                                  .add(member
                                                                      .id);
                                                            } else {
                                                              _selectedStaffIds
                                                                  .remove(
                                                                member.id,
                                                              );
                                                            }
                                                          });
                                                          field.didChange(
                                                            _selectedStaffIds
                                                                .toSet(),
                                                          );
                                                          _validateIfNeeded();
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                ),
                                if (field.errorText != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    field.errorText!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.red,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _CommissionDialogLabel(
                            context.t('2. Set commission rate')),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            _CommissionRuleRadio(
                              label: context.t('Percentage (%)'),
                              value: CommissionRuleTypes.percentage,
                              groupValue: _ruleType,
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _ruleType = value;
                                        _syncRateFromSelectedService();
                                      });
                                      _validateIfNeeded();
                                    },
                            ),
                            _CommissionRuleRadio(
                              label: context.t('Fixed Amount (Rs.)'),
                              value: CommissionRuleTypes.fixed,
                              groupValue: _ruleType,
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _ruleType = value;
                                        _syncRateFromSelectedService();
                                      });
                                      _validateIfNeeded();
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _CommissionDialogLabel(context.t('Rate *')),
                        TextFormField(
                          controller: _valueController,
                          enabled: !_isSaving,
                          autofocus: false,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: _rateInputFormatters,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _dialogInputDecoration(
                            suffix: Text(
                              _ruleType == CommissionRuleTypes.percentage
                                  ? '%'
                                  : '₹',
                              style: const TextStyle(
                                color: Color(0xFF8A8178),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final message = _rateValidationMessage(value);
                            return message.isEmpty ? null : message;
                          },
                          onChanged: _isSaving ? null : _handleRateChanged,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CommissionDialogLabel(
                                    context.t('Effective from'),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap:
                                        _isSaving ? null : _pickEffectiveDate,
                                    child: Ink(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 13,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFE1D6CB),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              DateFormat('dd/MM/yyyy')
                                                  .format(_effectiveFrom),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF1C1917),
                                              ),
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today_outlined,
                                            size: 16,
                                            color: AppColors.starColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _CommissionDialogLabel(context.t('Notes')),
                                  TextFormField(
                                    controller: _notesController,
                                    enabled: !_isSaving,
                                    autofocus: false,
                                    maxLines: 1,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: _dialogInputDecoration(
                                      hintText: context.t('Optional'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE6C978)),
                          ),
                          child: Text(
                            selectedService == null
                                ? context.t(
                                    'This rate overrides the default commission for the selected staff on this service.',
                                  )
                                : context.t(
                                    'This rate overrides the default ${_serviceDefaultCommissionLabel(selectedService)} commission for the selected staff on this service.',
                                  ),
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              color: Color(0xFF8A5A00),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDialogActionRow(context),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CommissionDialogLabel extends StatelessWidget {
  const _CommissionDialogLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: Color(0xFF7A7169),
        ),
      ),
    );
  }
}

class _CommissionRuleRadio extends StatelessWidget {
  const _CommissionRuleRadio({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onChanged == null ? null : () => onChanged!(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.starColor : const Color(0xFFB8AEA5),
                width: selected ? 2 : 1.4,
              ),
            ),
            child: selected
                ? Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.starColor,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2A2622),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffPickerHeaderRow extends StatelessWidget {
  const _StaffPickerHeaderRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool? value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F4F1),
        border: Border(
          bottom: BorderSide(color: Color(0xFFE8DED6)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Checkbox(
              value: value,
              tristate: true,
              onChanged: enabled ? onChanged : null,
              visualDensity: VisualDensity.compact,
              activeColor: AppColors.starColor,
            ),
          ),
          _StaffPickerHeaderCell(
            flex: 3,
            label: context.t('Staff'),
          ),
          _StaffPickerHeaderCell(
            flex: 2,
            label: context.t('Role'),
          ),
          _StaffPickerHeaderCell(
            flex: 2,
            label: context.t('Current rate'),
          ),
        ],
      ),
    );
  }
}

class _StaffPickerHeaderCell extends StatelessWidget {
  const _StaffPickerHeaderCell({
    required this.flex,
    required this.label,
  });

  final int flex;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: Color(0xFF7A7169),
        ),
      ),
    );
  }
}

class _StaffPickerRow extends StatelessWidget {
  const _StaffPickerRow({
    required this.member,
    required this.selected,
    required this.enabled,
    required this.currentRate,
    required this.onChanged,
  });

  final ProfileTeamMember member;
  final bool selected;
  final bool enabled;
  final String currentRate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!selected) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            SizedBox(
              width: 38,
              child: Checkbox(
                value: selected,
                onChanged: enabled
                    ? (value) {
                        onChanged(value ?? false);
                      }
                    : null,
                visualDensity: VisualDensity.compact,
                activeColor: AppColors.starColor,
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: const Color(0xFFF0E6D6),
                    child: Text(
                      _commissionInitials(member.name),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.starColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1C1917),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'GLW-${member.id}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8178),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                member.role.isEmpty ? context.t('Staff') : member.role,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4F1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE8DED6)),
                  ),
                  child: Text(
                    currentRate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.starColor,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
