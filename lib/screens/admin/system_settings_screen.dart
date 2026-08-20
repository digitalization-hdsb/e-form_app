import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_config.dart';
import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../providers/announcements_provider.dart';
import '../../widgets/form_list_tile.dart';

/// Mirrors the settings hub on pages/SuperAdminDashboard.tsx (`admin/settings`)
/// — all 5 of its settings cards: Manage Departments, Manage Home Poster,
/// Announcements, IT Admin Facilities, and IT Application Options.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key});

  static const _blue = Color(0xFF2563EB);
  static const _violet = Color(0xFF7C3AED);
  static const _amber = Color(0xFFD97706);
  static const _cyan = Color(0xFF0891B2);
  static const _indigo = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FormListTile(
          icon: Icons.create_new_folder_outlined,
          iconBackgroundColor: _blue,
          title: 'Manage Departments',
          description: 'Add, rename, or remove departments used throughout the system.',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _DepartmentsScreen())),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.image_outlined,
          iconBackgroundColor: _violet,
          title: 'Manage Home Poster',
          description: 'Upload, replace, enable, or disable the Home page poster.',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _HomePosterScreen())),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.campaign_outlined,
          iconBackgroundColor: _amber,
          title: 'Announcements',
          description: 'Publish and manage organization-wide announcements.',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AnnouncementsScreen())),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.dns_outlined,
          iconBackgroundColor: _cyan,
          title: 'IT Admin Facilities',
          description: 'Add, edit, or remove requisition checkboxes in the IT Request Form (Admin).',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ItOptionsScreen(kind: _ItOptionsKind.facilities))),
        ),
        const SizedBox(height: 12),
        FormListTile(
          icon: Icons.dns_outlined,
          iconBackgroundColor: _indigo,
          title: 'IT Application Options',
          description: 'Add, edit, or remove application checkboxes in the IT Request Form (Application).',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _ItOptionsScreen(kind: _ItOptionsKind.application))),
        ),
      ],
    );
  }
}

class _DepartmentsScreen extends StatefulWidget {
  const _DepartmentsScreen();

  @override
  State<_DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<_DepartmentsScreen> {
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  Map<String, dynamic>? _editingDepartment;
  final _editController = TextEditingController();
  bool _isRenaming = false;
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase.from('departments').select('*').order('name');
      setState(() {
        _departments = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _addDepartment() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Department'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Department name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await supabase.from('departments').insert({'name': controller.text.trim()});
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                _showError('Failed to add department: $e');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDepartment(Map<String, dynamic> department) async {
    setState(() => _deletingId = department['id']?.toString());
    try {
      final usersWithDept = await supabase.from('users').select('id').eq('department', department['name']).limit(1);
      if ((usersWithDept as List).isNotEmpty) {
        _showError('Cannot delete — users are still assigned to this department. Reassign them first.');
        return;
      }
      await supabase.from('departments').delete().eq('id', department['id']);
      await _load();
    } catch (e) {
      _showError('Failed to delete department: $e');
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  void _startRename(Map<String, dynamic> department) {
    setState(() {
      _editingDepartment = department;
      _editController.text = department['name']?.toString() ?? '';
    });
  }

  /// Renames a department and cascades the change to every user assigned to
  /// it — mirrors `handleRenameDepartment` in SuperAdminDashboard.tsx,
  /// including rolling the department rename back if the user cascade fails
  /// so the two tables never end up out of sync.
  Future<void> _renameDepartment() async {
    final currentName = _editingDepartment?['name']?.toString() ?? '';
    final newName = _editController.text.trim();
    if (newName.isEmpty) return;
    if (newName == currentName) {
      setState(() => _editingDepartment = null);
      return;
    }
    final duplicate = _departments.any((d) => d['name']?.toString().toLowerCase() == newName.toLowerCase() && d['name'] != currentName);
    if (duplicate) {
      _showError('A department named "$newName" already exists.');
      return;
    }

    setState(() => _isRenaming = true);
    try {
      await supabase.from('departments').update({'name': newName}).eq('name', currentName);
      try {
        await supabase.from('users').update({'department': newName}).eq('department', currentName);
      } catch (e) {
        await supabase.from('departments').update({'name': currentName}).eq('name', newName);
        rethrow;
      }
      setState(() => _editingDepartment = null);
      await _load();
      if (mounted) showSuccessSnackBar(context, 'Department renamed to "$newName".');
    } catch (e) {
      _showError('Failed to rename department: $e');
    } finally {
      if (mounted) setState(() => _isRenaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Manage Departments'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _addDepartment)]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final department in _departments) _departmentRow(department),
              ],
            ),
    );
  }

  Widget _departmentRow(Map<String, dynamic> department) {
    final isEditing = _editingDepartment != null && _editingDepartment!['id'] == department['id'];
    final isDeleting = _deletingId == department['id']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
      child: isEditing
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              title: TextField(
                controller: _editController,
                autofocus: true,
                onSubmitted: (_) => _renameDepartment(),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: _isRenaming ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)) : Icon(Icons.check, color: AppColors.primary),
                    onPressed: (_isRenaming || _editController.text.trim().isEmpty) ? null : _renameDepartment,
                  ),
                  IconButton(icon: Icon(Icons.close, color: AppColors.mutedForeground), onPressed: () => setState(() => _editingDepartment = null)),
                ],
              ),
            )
          : ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(department['name']?.toString() ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: Icon(Icons.edit_outlined, color: AppColors.mutedForeground), tooltip: 'Rename Department', onPressed: () => _startRename(department)),
                  IconButton(
                    icon: isDeleting ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.destructive)) : Icon(Icons.delete_outline, color: AppColors.destructive),
                    tooltip: 'Delete Department',
                    onPressed: isDeleting ? null : () => _deleteDepartment(department),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HomePosterScreen extends StatefulWidget {
  const _HomePosterScreen();

  @override
  State<_HomePosterScreen> createState() => _HomePosterScreenState();
}

class _HomePosterScreenState extends State<_HomePosterScreen> {
  bool _enabled = false;
  String? _url;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await supabase.from('safety_dashboard_settings').select('value').eq('key', 'home_poster').maybeSingle();
      final value = row?['value'] as Map?;
      setState(() {
        _enabled = (value?['enabled'] as bool?) ?? false;
        _url = value?['url'] as String?;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final file = result.files.first;
      final path = 'public/home-poster_${DateTime.now().millisecondsSinceEpoch}_${file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      if (file.bytes != null) {
        await supabase.storage.from('form-attachments').uploadBinary(path, file.bytes!);
      } else if (file.path != null) {
        await supabase.storage.from('form-attachments').upload(path, File(file.path!));
      }
      final url = supabase.storage.from('form-attachments').getPublicUrl(path);
      await supabase.from('safety_dashboard_settings').upsert({
        'key': 'home_poster',
        'value': {'enabled': true, 'url': url, 'version': DateTime.now().toIso8601String()},
      });
      setState(() {
        _url = url;
        _enabled = true;
        _isSaving = false;
      });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) showErrorSnackBar(context, 'Upload failed: $e');
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await supabase.from('safety_dashboard_settings').upsert({
      'key': 'home_poster',
      'value': {'enabled': value, 'url': _url, 'version': DateTime.now().toIso8601String()},
    });
  }

  Future<void> _remove() async {
    setState(() {
      _url = null;
      _enabled = false;
    });
    await supabase.from('safety_dashboard_settings').upsert({
      'key': 'home_poster',
      'value': {'enabled': false, 'url': null, 'version': DateTime.now().toIso8601String()},
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Home Poster')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_url != null) ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(_url!, height: 180, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 14),
                SwitchListTile(value: _enabled, onChanged: _url == null ? null : _toggleEnabled, title: const Text('Show poster to all users on Home')),
                const SizedBox(height: 10),
                OutlinedButton.icon(onPressed: _isSaving ? null : _upload, icon: const Icon(Icons.upload_outlined), label: Text(_url == null ? 'Upload Poster' : 'Replace Poster')),
                if (_url != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _remove,
                    style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.destructive), foregroundColor: AppColors.destructive),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove Poster'),
                  ),
                ],
              ],
            ),
    );
  }
}

class _AnnouncementsScreen extends ConsumerStatefulWidget {
  const _AnnouncementsScreen();

  @override
  ConsumerState<_AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<_AnnouncementsScreen> {
  void _showAddDialog() {
    final controller = TextEditingController();
    bool active = true;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add Announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Announcement text...')),
              const SizedBox(height: 8),
              SwitchListTile(value: active, onChanged: (v) => setDialogState(() => active = v), title: const Text('Active', style: TextStyle(fontSize: 13)), contentPadding: EdgeInsets.zero),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await ref.read(announcementsProvider.notifier).add(controller.text, active);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Announcements'), actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showAddDialog)]),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.announcements.isEmpty
              ? Center(child: Text('No announcements yet.', style: TextStyle(color: AppColors.mutedForeground)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final a in state.announcements)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: a.isActive ? AppColors.primary.withValues(alpha: 0.05) : AppColors.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                          boxShadow: AppColors.cardShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: (a.isActive ? AppColors.success : AppColors.mutedForeground).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                a.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(color: a.isActive ? AppColors.success : AppColors.mutedForeground, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(a.content, style: TextStyle(fontSize: 13, color: a.isActive ? AppColors.foreground : AppColors.mutedForeground)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Spacer(),
                                IconButton(
                                  icon: Icon(Icons.campaign, size: 18, color: a.isActive ? AppColors.success : AppColors.mutedForeground),
                                  tooltip: a.isActive ? 'Deactivate' : 'Activate',
                                  onPressed: () => ref.read(announcementsProvider.notifier).update(a.id, isActive: !a.isActive),
                                ),
                                IconButton(icon: Icon(Icons.delete_outline, size: 18, color: AppColors.destructive), onPressed: () => ref.read(announcementsProvider.notifier).delete(a.id)),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
    );
  }
}

enum _ItOptionsKind { facilities, application }

extension on _ItOptionsKind {
  String get table => this == _ItOptionsKind.facilities ? 'it_admin_facilities' : 'it_application_options';
  String get title => this == _ItOptionsKind.facilities ? 'IT Admin Facilities' : 'IT Application Options';
  bool get hasRequiresDetails => this == _ItOptionsKind.facilities;
  String get singularLabel => this == _ItOptionsKind.facilities ? 'Facility' : 'Option';
}

/// Shared CRUD screen for the two IT requisition-checkbox settings tables —
/// mirrors ITAdminFacilitiesSettings.tsx / ITApplicationOptionsSettings.tsx.
/// Both tables share the same shape (name + sort_order); only the "Admin"
/// variant additionally has a `requires_details` flag.
class _ItOptionsScreen extends StatefulWidget {
  final _ItOptionsKind kind;

  const _ItOptionsScreen({required this.kind});

  @override
  State<_ItOptionsScreen> createState() => _ItOptionsScreenState();
}

class _ItOptionsScreenState extends State<_ItOptionsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase.from(widget.kind.table).select('*').order('sort_order');
      setState(() {
        _items = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _showForm({Map<String, dynamic>? existing}) async {
    final controller = TextEditingController(text: existing?['name']?.toString() ?? '');
    var requiresDetails = (existing?['requires_details'] as bool?) ?? false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add ${widget.kind.singularLabel}' : 'Edit ${widget.kind.singularLabel}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, autofocus: true, maxLength: 80, decoration: const InputDecoration(labelText: 'Name')),
              if (widget.kind == _ItOptionsKind.application)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text("'ERP -' is added automatically in stored submissions.", style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                ),
              if (widget.kind.hasRequiresDetails)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: requiresDetails,
                  onChanged: (v) => setDialogState(() => requiresDetails = v),
                  title: const Text('Require additional details', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                try {
                  if (existing == null) {
                    final maxSort = _items.isEmpty ? 0 : _items.map((e) => (e['sort_order'] as num?)?.toInt() ?? 0).reduce((a, b) => a > b ? a : b);
                    await supabase.from(widget.kind.table).insert({
                      'name': name,
                      if (widget.kind.hasRequiresDetails) 'requires_details': requiresDetails,
                      'sort_order': maxSort + 10,
                    });
                  } else {
                    await supabase.from(widget.kind.table).update({
                      'name': name,
                      if (widget.kind.hasRequiresDetails) 'requires_details': requiresDetails,
                    }).eq('id', existing['id']);
                  }
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  await _load();
                } catch (e) {
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  _showError('Failed to save: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "${item['name']}"?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await supabase.from(widget.kind.table).delete().eq('id', item['id']);
      await _load();
    } catch (e) {
      _showError('Failed to delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.kind.title), actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showForm())]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text('No items yet.', style: TextStyle(color: AppColors.mutedForeground)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final item in _items)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item['name']?.toString() ?? ''),
                          subtitle: (widget.kind.hasRequiresDetails && item['requires_details'] == true)
                              ? Text('Additional details required', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: Icon(Icons.edit_outlined, color: AppColors.mutedForeground), onPressed: () => _showForm(existing: item)),
                              IconButton(icon: Icon(Icons.delete_outline, color: AppColors.destructive), onPressed: () => _delete(item)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
