import 'package:flutter/material.dart';

import '../features/profile/widgets/profile_subpage_app_bar.dart';
import '../features/salon/widgets/owner_branch_header_selector.dart';
import '../services/stylist_branch_selection.dart';
import '../utils/api_service.dart';
import '../utils/colors.dart';
import '../utils/localization_helper.dart';

const Color _rolesBackground = Color(0xFFFBFAF8);
const Color _rolesBorder = Color(0xFFE8DED6);
const Color _rolesText = Color(0xFF2B241D);
const Color _rolesMuted = Color(0xFF8C7A66);
const Color _rolesSurface = Colors.white;

class OwnerRolesPermissionsScreen extends StatefulWidget {
  const OwnerRolesPermissionsScreen({super.key});

  @override
  State<OwnerRolesPermissionsScreen> createState() =>
      _OwnerRolesPermissionsScreenState();
}

class _OwnerRolesPermissionsScreenState
    extends State<OwnerRolesPermissionsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<_RolesBranchOption> _branches = const [];
  List<_RoleItem> _roles = const [];
  List<_PermissionItem> _permissions = const [];
  int? _selectedBranchId;
  String _filter = 'all';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getSalonListApi();
      final branches = _extractBranches(response['data']);
      final selection = await StylistBranchSelectionStore.load();
      final selectedBranchId = branches.any(
        (branch) => branch.branchId == selection.branchId,
      )
          ? selection.branchId
          : (branches.isEmpty ? null : branches.first.branchId);

      if (!mounted) return;
      setState(() {
        _branches = branches;
        _selectedBranchId = selectedBranchId;
      });

      if (selectedBranchId == null) {
        setState(() => _isLoading = false);
        return;
      }

      await _loadRoles(selectedBranchId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRoles(int branchId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedBranchId = branchId;
    });

    try {
      final selected = _branches.where((item) => item.branchId == branchId);
      if (selected.isNotEmpty) {
        await StylistBranchSelectionStore.save(
          salonId: selected.first.salonId,
          branchId: selected.first.branchId,
          salonName: selected.first.salonName,
          branchName: selected.first.branchName,
        );
      }

      final response = await _apiService.getBranchRoles(branchId);
      final data = response['data'];
      final rawRoles = data is Map && data['roles'] is List
          ? data['roles'] as List
          : const [];
      final roles = rawRoles
          .whereType<Map>()
          .map((item) => _RoleItem.fromJson(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));
      final permissions = _permissionCatalog(roles);

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _permissions = permissions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<_RolesBranchOption> _extractBranches(dynamic data) {
    if (data is! List) return const [];
    final branches = <_RolesBranchOption>[];
    for (final salonEntry in data) {
      if (salonEntry is! Map) continue;
      final salon = Map<String, dynamic>.from(salonEntry);
      final salonId = _readInt(salon['id']);
      if (salonId == null) continue;
      final salonName = _cleanText(salon['name']);
      final rawBranches =
          salon['branches'] is List ? salon['branches'] as List : const [];
      for (final branchEntry in rawBranches) {
        if (branchEntry is! Map) continue;
        final branch = Map<String, dynamic>.from(branchEntry);
        final branchId = _readInt(branch['id']);
        if (branchId == null) continue;
        branches.add(
          _RolesBranchOption(
            salonId: salonId,
            branchId: branchId,
            salonName: salonName,
            branchName: _cleanText(branch['name']),
            address: _branchAddressSummary(branch['address']),
          ),
        );
      }
    }
    return branches;
  }

  List<_PermissionItem> _permissionCatalog(List<_RoleItem> roles) {
    final byId = <int, _PermissionItem>{};
    for (final role in roles) {
      for (final permission in role.permissions) {
        byId[permission.id] = permission;
      }
    }
    final permissions = byId.values.toList()
      ..sort((a, b) {
        final moduleCompare = a.module.compareTo(b.module);
        if (moduleCompare != 0) return moduleCompare;
        return a.action.index.compareTo(b.action.index);
      });
    return permissions;
  }

  List<_RoleItem> get _visibleRoles {
    final query = _searchController.text.trim().toLowerCase();
    return _roles.where((role) {
      if (_filter == 'system' && role.isCustom) return false;
      if (_filter == 'custom' && !role.isCustom) return false;
      if (query.isEmpty) return true;
      return role.label.toLowerCase().contains(query) ||
          role.code.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _openAddRole() async {
    final branchId = _selectedBranchId;
    if (branchId == null) return;
    final result = await showDialog<_RoleEditorResult>(
      context: context,
      builder: (context) => _RoleEditorDialog(
        title: 'Add Role',
        permissions: _permissions,
      ),
    );
    if (result == null) return;

    await _saveRole(
      branchId: branchId,
      label: result.label,
      permissionIds: result.permissionIds,
    );
  }

  Future<void> _openEditRole(_RoleItem role) async {
    final branchId = _selectedBranchId;
    if (branchId == null) return;
    final result = await showDialog<_RoleEditorResult>(
      context: context,
      builder: (context) => _RoleEditorDialog(
        title: 'Edit Role',
        role: role,
        permissions: _permissions,
      ),
    );
    if (result == null) return;

    await _saveRole(
      branchId: branchId,
      roleId: role.id,
      label: result.label,
      permissionIds: result.permissionIds,
    );
  }

  Future<void> _openRoleDetails(_RoleItem role) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _RoleEditorDialog(
        title: 'Role Details',
        role: role,
        permissions: _permissions,
        readOnly: true,
      ),
    );
  }

  Future<void> _saveRole({
    required int branchId,
    int? roleId,
    required String label,
    required List<int> permissionIds,
  }) async {
    final response = roleId == null
        ? await _apiService.createBranchRole(
            branchId: branchId,
            label: label,
            permissionIds: permissionIds,
          )
        : await _apiService.updateBranchRole(
            branchId: branchId,
            roleId: roleId,
            label: label,
            permissionIds: permissionIds,
          );

    if (!mounted) return;
    final success = response['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['message']?.toString() ??
              (success ? 'Role saved successfully.' : 'Unable to save role.'),
        ),
      ),
    );
    if (success) {
      await _loadRoles(branchId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _rolesBackground,
      appBar: buildProfileSubpageAppBar(title: context.t('Roles')),
      body: RefreshIndicator(
        color: AppColors.starColor,
        onRefresh: () async {
          final branchId = _selectedBranchId;
          if (branchId == null) {
            await _loadInitialData();
          } else {
            await _loadRoles(branchId);
          }
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _roles.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.starColor),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _RolesEmptyState(
            title: 'Unable to load roles',
            message: _errorMessage!,
            onRetry: _loadInitialData,
          ),
        ],
      );
    }

    if (_selectedBranchId == null) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: const [
          _RolesEmptyState(
            title: 'No branch found',
            message: 'Create or select a branch before managing roles.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 26),
      children: [
        _BranchSelector(
          branches: _branches,
          selectedBranchId: _selectedBranchId,
          onChanged: _loadRoles,
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final titleBlock = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('Roles & Permissions'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.starColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t(
                    'Manage branch roles and assigned permissions for the selected branch.',
                  ),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    color: _rolesMuted,
                  ),
                ),
              ],
            );
            final addButton = ElevatedButton.icon(
              onPressed: _openAddRole,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(context.t('Add Role')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleBlock,
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: addButton),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                addButton,
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _RolesTableCard(
          searchController: _searchController,
          filter: _filter,
          roles: _visibleRoles,
          isLoading: _isLoading,
          onSearchChanged: (_) => setState(() {}),
          onFilterChanged: (value) => setState(() => _filter = value),
          onView: _openRoleDetails,
          onEdit: _openEditRole,
        ),
      ],
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
  });

  final List<_RolesBranchOption> branches;
  final int? selectedBranchId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    _RolesBranchOption? selected;
    for (final branch in branches) {
      if (branch.branchId == selectedBranchId) {
        selected = branch;
        break;
      }
    }

    if (branches.isEmpty) {
      return _SharedBranchSelectorShell(
        child: Text(
          context.t('No branches available'),
          style: const TextStyle(
            color: _rolesMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final selectedBranch = selected ?? branches.first;
    return OwnerBranchHeaderSelector<int>(
      label: selectedBranch.displayName,
      options: branches
          .map(
            (branch) => OwnerBranchHeaderSelectorOption<int>(
              value: branch.branchId,
              label: branch.displayName,
              subtitle: branch.address,
            ),
          )
          .toList(),
      selectedValue: selectedBranch.branchId,
      placeholder: context.t('Select Branch'),
      isInteractive: branches.length > 1,
      onSelected: onChanged,
    );
  }
}

class _SharedBranchSelectorShell extends StatelessWidget {
  const _SharedBranchSelectorShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD9CBBB)),
      ),
      child: child,
    );
  }
}

class _RolesTableCard extends StatelessWidget {
  const _RolesTableCard({
    required this.searchController,
    required this.filter,
    required this.roles,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onView,
    required this.onEdit,
  });

  final TextEditingController searchController;
  final String filter;
  final List<_RoleItem> roles;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<_RoleItem> onView;
  final ValueChanged<_RoleItem> onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _rolesCardDecoration(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final search = TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    hintText: context.t('Search roles...'),
                    hintStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: Color(0xFFB0A49B),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _rolesBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.starColor),
                    ),
                  ),
                );
                final dropdown = DropdownButtonFormField<String>(
                  initialValue: filter,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _rolesBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.starColor),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Roles')),
                    DropdownMenuItem(
                        value: 'system', child: Text('System Roles')),
                    DropdownMenuItem(
                        value: 'custom', child: Text('Custom Roles')),
                  ],
                  onChanged: (value) {
                    if (value != null) onFilterChanged(value);
                  },
                );
                if (compact) {
                  return Column(
                    children: [
                      search,
                      const SizedBox(height: 12),
                      dropdown,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 18),
                    SizedBox(width: 210, child: dropdown),
                  ],
                );
              },
            ),
          ),
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          const Divider(height: 1, color: _rolesBorder),
          if (roles.isEmpty)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Center(
                  child: Text(
                    context.t('No roles found.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: _rolesMuted,
                    ),
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 780),
                child: Column(
                  children: [
                    const _RolesTableHeader(),
                    for (final role in roles)
                      _RoleRow(
                        role: role,
                        onView: () => onView(role),
                        onEdit: () => onEdit(role),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RolesTableHeader extends StatelessWidget {
  const _RolesTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
      color: AppColors.starColor,
    );
    return Container(
      height: 44,
      color: const Color(0xFFFFFAF7),
      child: const Row(
        children: [
          SizedBox(width: 210, child: _HeaderCell('Role Name', style)),
          SizedBox(width: 160, child: _HeaderCell('Role Type', style)),
          SizedBox(width: 150, child: _HeaderCell('Permissions', style)),
          SizedBox(width: 110, child: _HeaderCell('Priority', style)),
          SizedBox(width: 128, child: _HeaderCell('Actions', style)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.style);

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(label.toUpperCase(), style: style),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({
    required this.role,
    required this.onView,
    required this.onEdit,
  });

  final _RoleItem role;
  final VoidCallback onView;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _rolesBorder)),
      ),
      child: Row(
        children: [
          SizedBox(width: 210, child: _BodyCell(role.label, bold: true)),
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E4D7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    role.isCustom ? 'Custom Role' : 'System Role',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.starColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 150,
            child: _BodyCell('${role.permissions.length} permissions'),
          ),
          SizedBox(width: 110, child: _BodyCell('${role.priority}')),
          SizedBox(
            width: 128,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: _rolesText,
                ),
                IconButton(
                  tooltip: 'View',
                  visualDensity: VisualDensity.compact,
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                  onPressed: onView,
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                  color: _rolesText,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {this.bold = false});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          color: _rolesText,
        ),
      ),
    );
  }
}

class _RoleEditorDialog extends StatefulWidget {
  const _RoleEditorDialog({
    required this.title,
    required this.permissions,
    this.role,
    this.readOnly = false,
  });

  final String title;
  final _RoleItem? role;
  final List<_PermissionItem> permissions;
  final bool readOnly;

  @override
  State<_RoleEditorDialog> createState() => _RoleEditorDialogState();
}

class _RoleEditorDialogState extends State<_RoleEditorDialog> {
  late final TextEditingController _nameController;
  late final Set<int> _selectedPermissionIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.role?.label ?? '');
    _selectedPermissionIds =
        widget.role?.permissions.map((item) => item.id).toSet() ?? <int>{};
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Map<String, Map<_PermissionAction, _PermissionItem>>
      get _permissionsByModule {
    final grouped = <String, Map<_PermissionAction, _PermissionItem>>{};
    for (final permission in widget.permissions) {
      grouped.putIfAbsent(permission.module,
              () => <_PermissionAction, _PermissionItem>{})[permission.action] =
          permission;
    }
    return grouped;
  }

  void _selectAll() {
    setState(() {
      _selectedPermissionIds
        ..clear()
        ..addAll(widget.permissions.map((item) => item.id));
    });
  }

  void _selectViewOnly() {
    setState(() {
      _selectedPermissionIds
        ..clear()
        ..addAll(
          widget.permissions
              .where((item) => item.action == _PermissionAction.view)
              .map((item) => item.id),
        );
    });
  }

  void _submit() {
    final label = _nameController.text.trim();
    if (label.isEmpty) return;
    Navigator.pop(
      context,
      _RoleEditorResult(
        label: label,
        permissionIds: _selectedPermissionIds.toList()..sort(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modules = _permissionsByModule.keys.toList()..sort();
    final readOnly = widget.readOnly;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(widget.title),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _rolesText,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.t(
                              readOnly
                                  ? 'Review access levels for the selected branch.'
                                  : 'Assign access levels for the selected branch.',
                            ),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 10,
                              color: _rolesMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _rolesBorder),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('Role Name').toUpperCase(),
                        style: _smallGoldLabelStyle(),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 260,
                        child: TextField(
                          controller: _nameController,
                          readOnly: readOnly,
                          decoration: InputDecoration(
                            hintText: context.t('Receptionist'),
                            filled: true,
                            fillColor: const Color(0xFFFFFAF1),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE8C774)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide:
                                  const BorderSide(color: AppColors.starColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _PermissionToolbar(
                        readOnly: readOnly,
                        onSelectAll: _selectAll,
                        onSelectViewOnly: _selectViewOnly,
                        onClearAll: () =>
                            setState(_selectedPermissionIds.clear),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _PermissionMatrix(
                          modules: modules,
                          permissionsByModule: _permissionsByModule,
                          selectedPermissionIds: _selectedPermissionIds,
                          readOnly: readOnly,
                          onChanged: (permissionId, selected) {
                            setState(() {
                              if (selected) {
                                _selectedPermissionIds.add(permissionId);
                              } else {
                                _selectedPermissionIds.remove(permissionId);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: _rolesBorder),
              Padding(
                padding: const EdgeInsets.all(14),
                child: _RoleDialogFooter(
                  selectedCount: _selectedPermissionIds.length,
                  readOnly: readOnly,
                  actionLabel: context
                      .t(widget.role == null ? 'Create Role' : 'Save Changes'),
                  onCancel: () => Navigator.pop(context),
                  onSubmit: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionToolbar extends StatelessWidget {
  const _PermissionToolbar({
    required this.readOnly,
    required this.onSelectAll,
    required this.onSelectViewOnly,
    required this.onClearAll,
  });

  final bool readOnly;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectViewOnly;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('Assign Permissions'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: _rolesText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.t(
            'Select the actions this role can perform across branch modules.',
          ),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10,
            color: _rolesMuted,
          ),
        ),
      ],
    );

    if (readOnly) return copy;

    final actions = [
      TextButton(
        onPressed: onSelectAll,
        child: Text(context.t('Select All')),
      ),
      TextButton(
        onPressed: onSelectViewOnly,
        child: Text(context.t('Select View Only')),
      ),
      TextButton(
        onPressed: onClearAll,
        child: Text(context.t('Clear All')),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              copy,
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: actions),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: copy),
            for (final action in actions) action,
          ],
        );
      },
    );
  }
}

class _RoleDialogFooter extends StatelessWidget {
  const _RoleDialogFooter({
    required this.selectedCount,
    required this.readOnly,
    required this.actionLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final int selectedCount;
  final bool readOnly;
  final String actionLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final selectedText = Text(
      '$selectedCount permissions selected',
      style: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        color: _rolesMuted,
      ),
    );

    Widget outlinedButton(String label, VoidCallback onPressed) {
      return SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text(context.t(label)),
        ),
      );
    }

    Widget primaryButton() {
      return SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.starColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          child: Text(actionLabel),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              selectedText,
              const SizedBox(height: 10),
              if (readOnly)
                outlinedButton('Close', onCancel)
              else
                Row(
                  children: [
                    Expanded(child: outlinedButton('Cancel', onCancel)),
                    const SizedBox(width: 10),
                    Expanded(child: primaryButton()),
                  ],
                ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: selectedText),
            if (readOnly)
              SizedBox(width: 120, child: outlinedButton('Close', onCancel))
            else ...[
              SizedBox(width: 120, child: outlinedButton('Cancel', onCancel)),
              const SizedBox(width: 10),
              SizedBox(width: 150, child: primaryButton()),
            ],
          ],
        );
      },
    );
  }
}

class _PermissionMatrix extends StatelessWidget {
  const _PermissionMatrix({
    required this.modules,
    required this.permissionsByModule,
    required this.selectedPermissionIds,
    required this.readOnly,
    required this.onChanged,
  });

  final List<String> modules;
  final Map<String, Map<_PermissionAction, _PermissionItem>>
      permissionsByModule;
  final Set<int> selectedPermissionIds;
  final bool readOnly;
  final void Function(int permissionId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    const actions = _PermissionAction.values;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8C774)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            height: 34,
            color: const Color(0xFFFFFAF1),
            child: Row(
              children: [
                SizedBox(
                  width: 210,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Module'.toUpperCase(),
                        style: _smallGoldLabelStyle()),
                  ),
                ),
                for (final action in actions)
                  SizedBox(
                    width: 82,
                    child: Center(
                      child: Text(
                        action.label.toUpperCase(),
                        style: _smallGoldLabelStyle(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final module in modules)
            Container(
              height: 34,
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8C774))),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 210,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        module,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _rolesText,
                        ),
                      ),
                    ),
                  ),
                  for (final action in actions)
                    SizedBox(
                      width: 82,
                      child: Center(
                        child: _PermissionCheckbox(
                          permission: permissionsByModule[module]?[action],
                          selectedPermissionIds: selectedPermissionIds,
                          readOnly: readOnly,
                          onChanged: onChanged,
                        ),
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

class _PermissionCheckbox extends StatelessWidget {
  const _PermissionCheckbox({
    required this.permission,
    required this.selectedPermissionIds,
    required this.readOnly,
    required this.onChanged,
  });

  final _PermissionItem? permission;
  final Set<int> selectedPermissionIds;
  final bool readOnly;
  final void Function(int permissionId, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    final permission = this.permission;
    if (permission == null) {
      return const Text(
        '-',
        style: TextStyle(color: _rolesMuted, fontSize: 11),
      );
    }
    final selected = selectedPermissionIds.contains(permission.id);
    return Checkbox(
      value: selected,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      activeColor: AppColors.starColor,
      onChanged:
          readOnly ? null : (value) => onChanged(permission.id, value ?? false),
    );
  }
}

class _RolesEmptyState extends StatelessWidget {
  const _RolesEmptyState({
    required this.title,
    required this.message,
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _rolesCardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.admin_panel_settings_outlined,
              color: AppColors.starColor, size: 32),
          const SizedBox(height: 10),
          Text(
            context.t(title),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _rolesText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t(message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: _rolesMuted,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.starColor,
                foregroundColor: Colors.white,
              ),
              child: Text(context.t('Try Again')),
            ),
          ],
        ],
      ),
    );
  }
}

class _RolesBranchOption {
  const _RolesBranchOption({
    required this.salonId,
    required this.branchId,
    required this.salonName,
    required this.branchName,
    required this.address,
  });

  final int salonId;
  final int branchId;
  final String salonName;
  final String branchName;
  final String address;

  String get displayName => branchName.isEmpty ? salonName : branchName;
}

class _RoleItem {
  const _RoleItem({
    required this.id,
    required this.code,
    required this.label,
    required this.scopeType,
    required this.branchId,
    required this.priority,
    required this.permissions,
  });

  factory _RoleItem.fromJson(Map<String, dynamic> json) {
    return _RoleItem(
      id: _readInt(json['id']) ?? 0,
      code: _cleanText(json['code']),
      label: _cleanText(json['label']).isEmpty
          ? 'Role'
          : _cleanText(json['label']),
      scopeType: _cleanText(json['scopeType']),
      branchId: _readInt(json['branchId']),
      priority: _readInt(json['priority']) ?? 999,
      permissions: json['permissions'] is List
          ? (json['permissions'] as List)
              .whereType<Map>()
              .map((item) =>
                  _PermissionItem.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.id > 0)
              .toList()
          : const [],
    );
  }

  final int id;
  final String code;
  final String label;
  final String scopeType;
  final int? branchId;
  final int priority;
  final List<_PermissionItem> permissions;

  bool get isCustom =>
      scopeType.toLowerCase() == 'branch' ||
      scopeType.toLowerCase() == 'custom';
}

class _PermissionItem {
  const _PermissionItem({
    required this.id,
    required this.module,
    required this.key,
    required this.label,
    required this.action,
  });

  factory _PermissionItem.fromJson(Map<String, dynamic> json) {
    final key = _cleanText(json['key']);
    return _PermissionItem(
      id: _readInt(json['id']) ?? 0,
      module: _cleanText(json['module']).isEmpty
          ? 'Other'
          : _cleanText(json['module']),
      key: key,
      label: _cleanText(json['label']),
      action: _PermissionAction.fromKey(key),
    );
  }

  final int id;
  final String module;
  final String key;
  final String label;
  final _PermissionAction action;
}

enum _PermissionAction {
  create('Create'),
  view('View'),
  update('Update'),
  delete('Delete'),
  export('Export');

  const _PermissionAction(this.label);

  final String label;

  static _PermissionAction fromKey(String key) {
    final suffix = key.split('.').last.toLowerCase();
    switch (suffix) {
      case 'create':
        return _PermissionAction.create;
      case 'update':
      case 'toggle_status':
        return _PermissionAction.update;
      case 'delete':
        return _PermissionAction.delete;
      case 'export':
        return _PermissionAction.export;
      case 'view':
      default:
        return _PermissionAction.view;
    }
  }
}

class _RoleEditorResult {
  const _RoleEditorResult({
    required this.label,
    required this.permissionIds,
  });

  final String label;
  final List<int> permissionIds;
}

BoxDecoration _rolesCardDecoration() {
  return BoxDecoration(
    color: _rolesSurface,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _rolesBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0D000000),
        blurRadius: 12,
        offset: Offset(0, 5),
      ),
    ],
  );
}

TextStyle _smallGoldLabelStyle() {
  return const TextStyle(
    fontFamily: 'Manrope',
    fontSize: 9,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: AppColors.starColor,
  );
}

String _cleanText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return text;
}

String _branchAddressSummary(dynamic rawAddress) {
  if (rawAddress is! Map) return '';
  final address = Map<String, dynamic>.from(rawAddress);
  final parts = <String>[];

  void push(dynamic value) {
    final text = _cleanText(value);
    if (text.isNotEmpty && !parts.contains(text)) parts.add(text);
  }

  push(address['line1']);
  push(address['line2']);
  push(address['village']);
  push(address['district']);
  push(address['city']);
  push(address['state']);
  push(address['postalCode']);
  push(address['country']);
  return parts.join(', ');
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}
