import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../data/erp_authorization_rights.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../providers/users_provider.dart';
import '../../widgets/approver_dropdown.dart';
import '../../widgets/form_section_card.dart';

class ItFacilitiesRequisitionFormScreen extends ConsumerStatefulWidget {
  final String variant; // admin | application

  const ItFacilitiesRequisitionFormScreen({super.key, required this.variant});

  @override
  ConsumerState<ItFacilitiesRequisitionFormScreen> createState() => _ItFacilitiesRequisitionFormScreenState();
}

class _ItFacilitiesRequisitionFormScreenState extends ConsumerState<ItFacilitiesRequisitionFormScreen> {
  bool get _isAdmin => widget.variant == 'admin';

  List<Map<String, dynamic>> _facilityOptions = []; // {name, requires_details}
  bool _loadingFacilities = true;
  final Set<String> _selectedFacilities = {};
  final Map<String, TextEditingController> _facilityDetailControllers = {};
  final _othersController = TextEditingController();
  final Set<int> _selectedRightIds = {};
  List<AuthorizationRight> _allRights = [];
  String? _hos;
  String? _hod;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
    if (!_isAdmin) loadAuthorizationRights().then((rights) => setState(() => _allRights = rights));
  }

  Future<void> _loadFacilities() async {
    try {
      if (_isAdmin) {
        final data = await supabase.from('it_admin_facilities').select('*').order('sort_order');
        setState(() {
          _facilityOptions = (data as List).map((e) => {'name': e['name'], 'requires_details': e['requires_details'] ?? false}).toList();
          _loadingFacilities = false;
        });
      } else {
        final data = await supabase.from('it_application_options').select('*').order('sort_order');
        setState(() {
          _facilityOptions = (data as List).map((e) => {'name': 'ERP - ${e['name']}', 'requires_details': false}).toList();
          _loadingFacilities = false;
        });
      }
    } catch (_) {
      setState(() => _loadingFacilities = false);
    }
  }

  @override
  void dispose() {
    _othersController.dispose();
    for (final c in _facilityDetailControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _detailControllerFor(String facility) => _facilityDetailControllers.putIfAbsent(facility, () => TextEditingController());

  List<String> get _selectedErpModules =>
      _selectedFacilities.where((f) => f.startsWith('ERP - ')).map((f) => f.replaceFirst('ERP - ', '')).toList();

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    if (_selectedFacilities.isEmpty) return _showError('Select at least one IT facility.');
    if (_isAdmin) {
      final missing = _facilityOptions.where((f) => f['requires_details'] == true && _selectedFacilities.contains(f['name']) && _detailControllerFor(f['name'] as String).text.trim().isEmpty);
      if (missing.isNotEmpty) return _showError('Enter the additional details required for ${missing.first['name']}.');
    } else {
      for (final module in _selectedErpModules) {
        final moduleRights = _allRights.where((r) => r.module.toLowerCase() == module.toLowerCase()).toList();
        if (moduleRights.isNotEmpty && !moduleRights.any((r) => _selectedRightIds.contains(r.id))) {
          return _showError('Select at least one access right for $module.');
        }
      }
    }
    if (_hos == null || _hod == null) return _showError('Select both the Head of Section and Head of Department.');

    setState(() => _isSubmitting = true);
    final facilityDetails = {
      for (final f in _selectedFacilities)
        if (_facilityDetailControllers[f]?.text.trim().isNotEmpty ?? false) f: _facilityDetailControllers[f]!.text.trim(),
    };
    final selectedRights = _allRights.where((r) => _selectedRightIds.contains(r.id)).toList();

    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: _isAdmin ? 'it_admin_request' : 'it_application_request',
      status: _hos == 'N/A' ? 'approved_hos' : 'pending',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'staffId': user.employeeId,
        'position': user.position,
        'employeeInfo': {'employeeNumber': user.employeeId, 'position': user.position},
        'facilities': _selectedFacilities.toList(),
        'facilityDetails': facilityDetails,
        'sharePointFolder': facilityDetails['SharePoint'] ?? '',
        'erpAuthorizationRightIds': selectedRights.map((r) => r.id).toList(),
        'erpAuthorizationRights': selectedRights.map((r) => r.toMap()).toList(),
        'requestSummary': '${_selectedFacilities.length} facilities requested',
        'others': _othersController.text.trim(),
        'hosName': _hos,
        'hodName': _hod,
      },
    );

    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      showSuccessSnackBar(context, 'IT Request Form (${_isAdmin ? 'Admin' : 'Application'}) submitted successfully.');
      context.go('/home');
    } else {
      _showError(result.error ?? 'Submission failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final usersState = ref.watch(usersProvider);
    final hosUsers = usersState.byRole('hos');
    final hodUsers = usersState.byRole('hod');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('IT Request Form (${_isAdmin ? 'Admin' : 'Application'})')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FormSectionCard(
            number: '01',
            icon: Icons.person_outline,
            title: 'Employee Details',
            child: PrefilledDetailsBox(rows: {
              'Name': user?.name ?? '',
              'Position': user?.position ?? '',
              'Staff ID': user?.employeeId ?? '',
              'Department': user?.department ?? '',
            }),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '02',
            icon: Icons.check_box_outlined,
            title: 'Requisition',
            child: _loadingFacilities
                ? const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Select all IT facilities required.', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _facilityOptions.map((f) {
                          final name = f['name'] as String;
                          final label = _isAdmin ? name : name.replaceFirst('ERP - ', '');
                          final selected = _selectedFacilities.contains(name);
                          return FilterChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (v) => setState(() => v ? _selectedFacilities.add(name) : _selectedFacilities.remove(name)),
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(fontSize: 12, color: selected ? AppColors.primary : AppColors.foreground, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                          );
                        }).toList(),
                      ),
                      if (_isAdmin)
                        for (final f in _facilityOptions)
                          if (f['requires_details'] == true && _selectedFacilities.contains(f['name']))
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _detailControllerFor(f['name'] as String),
                                decoration: InputDecoration(labelText: '${f['name']} details *'),
                              ),
                            ),
                      if (_isAdmin) ...[
                        const SizedBox(height: 12),
                        TextField(controller: _othersController, maxLines: 3, decoration: const InputDecoration(labelText: 'Others', hintText: 'Enter any other IT facility required...')),
                      ],
                      if (!_isAdmin && _selectedErpModules.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 8),
                        const Text('ERP User Access Authorization', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${_selectedRightIds.length} selected', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                        const SizedBox(height: 8),
                        for (final module in _selectedErpModules) _moduleRightsExpansion(module),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          FormSectionCard(
            number: '03',
            icon: Icons.person_outline,
            title: 'Approvals',
            child: Column(
              children: [
                ApproverDropdown(label: 'Head of Section', options: hosUsers, value: _hos, isLoading: usersState.isLoading, includeNotApplicable: true, onChanged: (v) => setState(() => _hos = v)),
                const SizedBox(height: 12),
                ApproverDropdown(label: 'Head of Department', options: hodUsers, value: _hod, isLoading: usersState.isLoading, onChanged: (v) => setState(() => _hod = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                : const Text('Submit Requisition'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _moduleRightsExpansion(String module) {
    final rights = _allRights.where((r) => r.module.toLowerCase() == module.toLowerCase()).toList();
    final selectedCount = rights.where((r) => _selectedRightIds.contains(r.id)).length;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(module, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text('$selectedCount of ${rights.length} selected', style: TextStyle(fontSize: 11, color: AppColors.primary)),
        children: rights.map((r) {
          final checked = _selectedRightIds.contains(r.id);
          return CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: checked,
            onChanged: (v) => setState(() => v == true ? _selectedRightIds.add(r.id) : _selectedRightIds.remove(r.id)),
            title: Text(r.right, style: const TextStyle(fontSize: 12.5)),
          );
        }).toList(),
      ),
    );
  }
}
