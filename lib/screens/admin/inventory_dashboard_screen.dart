import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../models/submission.dart';
import '../../providers/auth_provider.dart';
import '../../providers/submissions_provider.dart';
import '../../screens/hr/ppe_item_catalog.dart';

/// Verbatim port of SAFETY_STOCK_LEVELS in components/InventoryDashboard.tsx
/// — keyed by item name alone for single-size items, or `"name - size"`
/// for items with multiple sizes, falling back to "default" otherwise.
const Map<String, int> _safetyStockLevels = {
  'default': 5,
  'Crane Vest': 5,
  'Earplug': 20,
  'Forklift Vest': 5,
  'Safety Goggles': 20,
  'Safety Helmet': 20,
  'Safety Insert': 15,
  'Cargo Pants - 26"': 10, 'Cargo Pants - 28"': 10, 'Cargo Pants - 30"': 20, 'Cargo Pants - 32"': 20,
  'Cargo Pants - 34"': 20, 'Cargo Pants - 36"': 20, 'Cargo Pants - 38"': 10, 'Cargo Pants - 40"': 10,
  'Cargo Pants - 42"': 8, 'Cargo Pants - 44"': 6, 'Cargo Pants - 46"': 6, 'Cargo Pants - 48"': 4, 'Cargo Pants - 50"': 4,
  'Company Shirt - XS': 6, 'Company Shirt - S': 10, 'Company Shirt - M': 20, 'Company Shirt - L': 20,
  'Company Shirt - XL': 20, 'Company Shirt - 2XL': 20, 'Company Shirt - 3XL': 8, 'Company Shirt - 4XL': 6, 'Company Shirt - 5XL': 6,
  'Company Shirt (Long Sleeve) - XS': 6, 'Company Shirt (Long Sleeve) - S': 10, 'Company Shirt (Long Sleeve) - M': 20,
  'Company Shirt (Long Sleeve) - L': 20, 'Company Shirt (Long Sleeve) - XL': 20, 'Company Shirt (Long Sleeve) - 2XL': 20,
  'Company Shirt (Long Sleeve) - 3XL': 8, 'Company Shirt (Long Sleeve) - 4XL': 6, 'Company Shirt (Long Sleeve) - 5XL': 6,
  'Company T-Shirt (Long Sleeve) - XS': 6, 'Company T-Shirt (Long Sleeve) - S': 10, 'Company T-Shirt (Long Sleeve) - M': 20,
  'Company T-Shirt (Long Sleeve) - L': 20, 'Company T-Shirt (Long Sleeve) - XL': 20, 'Company T-Shirt (Long Sleeve) - 2XL': 20,
  'Company T-Shirt (Long Sleeve) - 3XL': 8, 'Company T-Shirt (Long Sleeve) - 4XL': 6, 'Company T-Shirt (Long Sleeve) - 5XL': 6,
  'Company T-Shirt (Short Sleeve) - XS': 6, 'Company T-Shirt (Short Sleeve) - S': 10, 'Company T-Shirt (Short Sleeve) - M': 20,
  'Company T-Shirt (Short Sleeve) - L': 20, 'Company T-Shirt (Short Sleeve) - XL': 20, 'Company T-Shirt (Short Sleeve) - 2XL': 20,
  'Company T-Shirt (Short Sleeve) - 3XL': 10, 'Company T-Shirt (Short Sleeve) - 4XL': 6, 'Company T-Shirt (Short Sleeve) - 5XL': 6,
  'Safety Shoe - Size 3': 3, 'Safety Shoe - Size 4': 3, 'Safety Shoe - Size 5': 5, 'Safety Shoe - Size 6': 5,
  'Safety Shoe - Size 7': 10, 'Safety Shoe - Size 8': 10, 'Safety Shoe - Size 9': 10, 'Safety Shoe - Size 10': 10,
  'Safety Shoe - Size 11': 5, 'Safety Shoe - Size 12': 3, 'Safety Shoe - Size 13': 3,
};

int _safetyStockLevel(String key) => _safetyStockLevels[key] ?? _safetyStockLevels['default']!;

const _categories = [('ppe', 'PPE'), ('uniform', 'Uniform'), ('office', 'Office Supply')];

class _StockLine {
  final String itemName;
  final String size;
  int added = 0;
  int distributed = 0;
  _StockLine(this.itemName, this.size);
  int get remaining => added - distributed;
  String get key => size.isEmpty || size == 'N/A' ? itemName : '$itemName - $size';
}

enum _View { stock, activity }

enum _ActivityFilter { all, restock, distribution }

/// Mirrors components/InventoryDashboard.tsx in full: stat cards, a
/// category-filtered + searchable stock table with a distributed-percent
/// bar, a Recent Activity feed, and the Add/Update Stock + Manage Prices
/// actions. There is no dedicated inventory table on the backend — stock is
/// derived entirely from `inventory_addition` (restock) vs
/// `ppe_request`/`ppe_purchase` (distribution) submissions, same as web.
class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() => _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends ConsumerState<InventoryDashboardScreen> {
  final _allItems = [...ppeItems, ...uniformItems, ...officeItems];
  _View _view = _View.stock;
  String _categoryTab = 'ppe';
  String _search = '';
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  bool _viewAllActivity = false;

  Map<String, String> _categoryFor(List<Submission> submissions) {
    final map = <String, String>{};
    for (final i in ppeItems) {
      map[i.name] = 'ppe';
    }
    for (final i in uniformItems) {
      map[i.name] = 'uniform';
    }
    for (final i in officeItems) {
      map[i.name] = 'office';
    }
    for (final s in submissions) {
      if (s.formType != 'inventory_addition') continue;
      final name = s.data['itemName']?.toString();
      final category = s.data['category']?.toString();
      if (name != null && name.isNotEmpty && category != null && category.isNotEmpty && category != 'other') {
        map[name] = category;
      }
    }
    return map;
  }

  Map<String, _StockLine> _computeStock(List<Submission> submissions) {
    final lines = <String, _StockLine>{};
    _StockLine lineFor(String name, String size) => lines.putIfAbsent('$name::$size', () => _StockLine(name, size));

    for (final s in submissions) {
      if (s.formType == 'inventory_addition' && s.status == 'approved') {
        final name = s.data['itemName']?.toString() ?? '';
        var size = s.data['size']?.toString() ?? '';
        if (size.isEmpty) size = _defaultSizeFor(name);
        final qty = int.tryParse(s.data['quantity']?.toString() ?? '') ?? 0;
        if (name.isNotEmpty) lineFor(name, size).added += qty;
      } else if ((s.formType == 'ppe_request' || s.formType == 'ppe_purchase') && s.status == 'approved') {
        final items = (s.data['items'] as List?) ?? [];
        for (final item in items) {
          final map = item as Map;
          final name = map['Item Name']?.toString() ?? '';
          var size = map['Size']?.toString() ?? '';
          if (size.isEmpty) size = _defaultSizeFor(name);
          final qty = int.tryParse(map['Quantity']?.toString() ?? '') ?? 0;
          if (name.isNotEmpty) lineFor(name, size).distributed += qty;
        }
      }
    }
    return lines;
  }

  String _defaultSizeFor(String name) {
    final match = _allItems.where((i) => i.name == name);
    if (match.isNotEmpty && match.first.sizes.length == 1) return match.first.sizes.first.size;
    return '';
  }

  String _formatActivityDescription(Submission s) {
    if (s.formType == 'inventory_addition') {
      final name = s.data['itemName']?.toString() ?? '';
      var size = s.data['size']?.toString() ?? '';
      if (size.isEmpty) size = _defaultSizeFor(name).isEmpty ? 'Standard' : _defaultSizeFor(name);
      return '+${s.data['quantity']}x $name ($size)';
    }
    final items = (s.data['items'] as List?) ?? [];
    return items.map((item) {
      final map = item as Map;
      final name = map['Item Name']?.toString() ?? '';
      var size = map['Size']?.toString() ?? '';
      if (size.isEmpty) size = _defaultSizeFor(name).isEmpty ? 'Standard' : _defaultSizeFor(name);
      return '${map['Quantity']}x $name ($size)';
    }).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submissionsProvider);
    final submissions = state.submissions;
    final stock = _computeStock(submissions);
    final categoryOf = _categoryFor(submissions);

    final allKeys = <String>{
      for (final item in _allItems)
        for (final s in item.sizes) (item.sizes.length == 1 ? item.name : '${item.name} - ${s.size}'),
      for (final line in stock.values) line.key,
    }.toList()
      ..sort();

    final filteredKeys = allKeys.where((k) {
      final itemName = k.contains(' - ') ? k.substring(0, k.indexOf(' - ')) : k;
      final matchesCategory = (categoryOf[itemName] ?? 'ppe') == _categoryTab;
      final matchesSearch = _search.isEmpty || itemName.toLowerCase().contains(_search.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    int totalFor(String key) {
      final line = stock.values.where((l) => l.key == key);
      return line.isEmpty ? 0 : line.first.added;
    }

    int distributedFor(String key) {
      final line = stock.values.where((l) => l.key == key);
      return line.isEmpty ? 0 : line.first.distributed;
    }

    final totalDistributed = stock.values.fold<int>(0, (sum, l) => sum + l.distributed);
    final lowStockCount = allKeys.where((k) => totalFor(k) - distributedFor(k) <= _safetyStockLevel(k)).length;

    return RefreshIndicator(
      onRefresh: () => ref.read(submissionsProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _statCard(Icons.inventory_2_outlined, 'Item Types', '${filteredKeys.length}', AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(child: _statCard(Icons.local_shipping_outlined, 'Distributed', '$totalDistributed', AppColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _statCard(Icons.warning_amber_outlined, 'Low Stock', '$lowStockCount', AppColors.destructive)),
            ],
          ),
          const SizedBox(height: 16),
          // Primary navigation: which view am I looking at. Kept visually
          // distinct (a filled segmented control) from the filter chips
          // below it, which only narrow down whichever view is active.
          SegmentedButton<_View>(
            segments: const [
              ButtonSegment(value: _View.stock, label: Text('Stock Levels'), icon: Icon(Icons.inventory_2_outlined, size: 16)),
              ButtonSegment(value: _View.activity, label: Text('Recent Activity'), icon: Icon(Icons.history, size: 16)),
            ],
            selected: {_view},
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _view = v.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.foreground,
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.onPrimary,
              side: BorderSide(color: AppColors.border),
              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          if (_view == _View.stock) ..._buildStockView(filteredKeys, totalFor, distributedFor) else ..._buildActivityView(submissions),
        ],
      ),
    );
  }

  List<Widget> _buildStockView(List<String> filteredKeys, int Function(String) totalFor, int Function(String) distributedFor) {
    return [
      // Actions — anything that changes data lives together, separate from
      // the read-only filters below.
      Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => showAddStockSheet(context, ref, _allItems),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add / Update Stock'),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => showManagePricesSheet(context, _allItems),
            icon: const Icon(Icons.sell_outlined, size: 18),
            label: const Text('Prices'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      // Filters — read-only, narrow down the list below.
      Text('CATEGORY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final c in _categories)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.$2),
                  selected: _categoryTab == c.$1,
                  onSelected: (_) => setState(() => _categoryTab = c.$1),
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: _categoryTab == c.$1 ? AppColors.onPrimary : AppColors.foreground, fontWeight: FontWeight.w600, fontSize: 12),
                  backgroundColor: AppColors.card,
                  side: BorderSide(color: AppColors.border),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search, size: 18), hintText: 'Search inventory...', isDense: true),
        onChanged: (v) => setState(() => _search = v),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Text('ITEMS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
          const Spacer(),
          Text('${filteredKeys.length}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground)),
        ],
      ),
      const SizedBox(height: 8),
      if (filteredKeys.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No items match your criteria.', style: TextStyle(color: AppColors.mutedForeground))))
      else
        for (final key in filteredKeys) _stockTile(key, totalFor(key), distributedFor(key)),
    ];
  }

  Widget _stockTile(String key, int total, int distributed) {
    final remaining = total - distributed;
    final threshold = _safetyStockLevel(key);
    final low = remaining <= threshold;
    final percent = total > 0 ? (distributed / total).clamp(0.0, 1.0) : 1.0;
    final itemName = key.contains(' - ') ? key.substring(0, key.indexOf(' - ')) : key;
    final size = key.contains(' - ') ? key.substring(key.indexOf(' - ') + 3) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: low ? AppColors.destructive.withValues(alpha: 0.5) : AppColors.border), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(text: itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (size != null) TextSpan(text: '  ($size)', style: TextStyle(fontSize: 11, color: AppColors.mutedForeground)),
                  ]),
                ),
              ),
              if (low) Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.destructive),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _statChip('Total', '$total'),
              const SizedBox(width: 8),
              _statChip('Out', '$distributed'),
              const SizedBox(width: 8),
              _statChip('Left', '$remaining', color: low ? AppColors.destructive : AppColors.primary),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(percent >= 0.9 ? AppColors.destructive : percent >= 0.7 ? AppColors.gold : AppColors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: '$label ', style: TextStyle(fontSize: 10.5, color: AppColors.mutedForeground)),
          TextSpan(text: value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color ?? AppColors.foreground)),
        ]),
      ),
    );
  }

  List<Widget> _buildActivityView(List<Submission> submissions) {
    final activity = submissions.where((s) {
      final isRelevant = (['ppe_request', 'ppe_purchase'].contains(s.formType) && s.status == 'approved') || s.formType == 'inventory_addition';
      if (!isRelevant) return false;
      switch (_activityFilter) {
        case _ActivityFilter.all:
          return true;
        case _ActivityFilter.restock:
          return s.formType == 'inventory_addition';
        case _ActivityFilter.distribution:
          return s.formType != 'inventory_addition';
      }
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse((a.data['lastUpdatedAt'] as String?) ?? a.submittedAt) ?? DateTime(0);
        final db = DateTime.tryParse((b.data['lastUpdatedAt'] as String?) ?? b.submittedAt) ?? DateTime(0);
        return db.compareTo(da);
      });

    final visible = _viewAllActivity ? activity : activity.take(30).toList();

    return [
      Text('FILTER', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _activityChip('All', _ActivityFilter.all),
            const SizedBox(width: 8),
            _activityChip('Distributed', _ActivityFilter.distribution),
            const SizedBox(width: 8),
            _activityChip('Restocked', _ActivityFilter.restock),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (visible.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 60), child: Center(child: Text('No recent inventory activity.', style: TextStyle(color: AppColors.mutedForeground))))
      else
        for (final s in visible) _activityTile(s),
      if (activity.length >= 30)
        Center(
          child: TextButton(
            onPressed: () => setState(() => _viewAllActivity = !_viewAllActivity),
            child: Text(_viewAllActivity ? 'Show Recent 30' : 'View All Activity'),
          ),
        ),
    ];
  }

  Widget _activityChip(String label, _ActivityFilter value) {
    final selected = _activityFilter == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      selected: selected,
      onSelected: (_) => setState(() {
        _activityFilter = value;
        _viewAllActivity = false;
      }),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? AppColors.onPrimary : AppColors.foreground, fontWeight: FontWeight.w600),
      backgroundColor: AppColors.card,
      side: BorderSide(color: AppColors.border),
    );
  }

  Widget _activityTile(Submission s) {
    final isRestock = s.formType == 'inventory_addition';
    final date = DateTime.tryParse((s.data['lastUpdatedAt'] as String?) ?? s.submittedAt);
    final badgeLabel = isRestock ? 'RESTOCK' : ((s.data['requestCategory'] as String?)?.toUpperCase() ?? 'PPE');
    final badgeColor = isRestock ? const Color(0xFF3B82F6) : AppColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: Text(s.employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: Text(badgeLabel, style: TextStyle(color: badgeColor, fontSize: 8.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              if (date != null) Text(DateFormat('d MMM, h:mm a').format(date), style: TextStyle(fontSize: 10, color: AppColors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 5),
          Text(_formatActivityDescription(s), style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
          if (isRestock && (s.data['poNumber'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 3),
            Text('PO Number: ${s.data['poNumber']}', style: TextStyle(fontSize: 10.5, color: AppColors.mutedForeground)),
          ],
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border), boxShadow: AppColors.cardShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 9.5, color: AppColors.mutedForeground, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Opens the Add/Update Stock sheet — mirrors the Sheet in
/// InventoryDashboard.tsx: pick a category, then an item (or a brand-new
/// item name), then a size if applicable, a quantity, and an optional PO
/// number.
void showAddStockSheet(BuildContext context, WidgetRef ref, List<CatalogItem> allItems) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _AddStockSheet(allItems: allItems),
  );
}

class _AddStockSheet extends ConsumerStatefulWidget {
  final List<CatalogItem> allItems;
  const _AddStockSheet({required this.allItems});

  @override
  ConsumerState<_AddStockSheet> createState() => _AddStockSheetState();
}

class _AddStockSheetState extends ConsumerState<_AddStockSheet> {
  String _category = 'ppe';
  String? _itemName;
  String? _size;
  final _customItemController = TextEditingController();
  final _qtyController = TextEditingController();
  final _poController = TextEditingController();
  bool _isSubmitting = false;

  List<CatalogItem> get _itemsForCategory => switch (_category) {
        'ppe' => ppeItems,
        'uniform' => uniformItems,
        _ => officeItems,
      };

  @override
  void dispose() {
    _customItemController.dispose();
    _qtyController.dispose();
    _poController.dispose();
    super.dispose();
  }

  void _showError(String message) => showErrorSnackBar(context, message);

  Future<void> _submit() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final isOther = _itemName == 'other';
    final name = isOther ? _customItemController.text.trim() : (_itemName ?? '');
    final selected = widget.allItems.where((i) => i.name == name);
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;

    if (name.isEmpty || qty <= 0 || (!isOther && selected.isNotEmpty && selected.first.sizes.length > 1 && _size == null)) {
      _showError('Please provide an item name, size (if applicable), and quantity.');
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(submissionsProvider.notifier).addSubmission(
      formType: 'inventory_addition',
      status: 'approved',
      submittedBy: user.id,
      employeeName: user.name,
      department: user.department,
      data: {
        'itemName': name,
        'size': _size ?? '',
        'quantity': qty,
        'category': _category,
        'poNumber': _poController.text.trim(),
      },
    );
    setState(() => _isSubmitting = false);
    if (!mounted) return;
    if (result.success) {
      Navigator.pop(context);
      showSuccessSnackBar(context, '$qty unit(s) added to $name stock.');
    } else {
      _showError(result.error ?? 'Failed to add stock.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _itemName == 'other';
    final selected = widget.allItems.where((i) => i.name == _itemName);
    final List<ItemSize> sizes = (!isOther && selected.isNotEmpty) ? selected.first.sizes : const [];

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Add / Update Stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Increase inventory for an existing item or add a new one.', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 18),
            Text('1. SELECT CATEGORY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final c in _categories)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: c == _categories.last ? 0 : 8),
                      child: OutlinedButton(
                        onPressed: () => setState(() {
                          _category = c.$1;
                          _itemName = null;
                          _size = null;
                        }),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _category == c.$1 ? AppColors.primary.withValues(alpha: 0.1) : null,
                          side: BorderSide(color: _category == c.$1 ? AppColors.primary : AppColors.border),
                          foregroundColor: _category == c.$1 ? AppColors.primary : AppColors.mutedForeground,
                        ),
                        child: Text(c.$2, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('2. SELECT ITEM', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.3)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              borderRadius: BorderRadius.circular(14),
              dropdownColor: AppColors.card,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
              initialValue: _itemName,
              isExpanded: true,
              hint: const Text('Choose an item...'),
              items: [
                for (final i in _itemsForCategory) DropdownMenuItem(value: i.name, child: Text(i.name, overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'other', child: Text('+ Add New Item', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
              ],
              onChanged: (v) => setState(() {
                _itemName = v;
                _size = null;
              }),
            ),
            if (isOther) ...[
              const SizedBox(height: 12),
              TextField(controller: _customItemController, decoration: const InputDecoration(labelText: 'New Item Name', hintText: 'e.g. Safety Glasses')),
            ],
            if (!isOther && sizes.isNotEmpty && sizes.length > 1) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                borderRadius: BorderRadius.circular(14),
                dropdownColor: AppColors.card,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.mutedForeground),
                initialValue: _size,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Size / Type'),
                items: sizes.map((s) => DropdownMenuItem(value: s.size, child: Text(s.size))).toList(),
                onChanged: (v) => setState(() => _size = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(controller: _qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '3. Quantity to Add')),
            const SizedBox(height: 12),
            TextField(controller: _poController, decoration: const InputDecoration(labelText: '4. PO Number (optional)')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryDark))
                    : const Text('Update Stock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the "Manage Item Prices" sheet — mirrors PriceManagementSheet in
/// InventoryDashboard.tsx. Like the website's version (which only ever
/// wrote to that browser's localStorage), this is a per-device override
/// stored locally, not synced through Supabase.
void showManagePricesSheet(BuildContext context, List<CatalogItem> allItems) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ManagePricesSheet(allItems: allItems),
  );
}

class _ManagePricesSheet extends StatefulWidget {
  final List<CatalogItem> allItems;
  const _ManagePricesSheet({required this.allItems});

  @override
  State<_ManagePricesSheet> createState() => _ManagePricesSheetState();
}

class _ManagePricesSheetState extends State<_ManagePricesSheet> {
  static const _prefsKey = 'hdsb_item_prices';
  String _category = 'ppe';
  Map<String, String> _overrides = {};
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('$_prefsKey::'));
    setState(() {
      _overrides = {for (final k in keys) k.substring('$_prefsKey::'.length): prefs.getString(k) ?? ''};
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    for (final entry in _overrides.entries) {
      if (entry.value.trim().isEmpty) {
        await prefs.remove('$_prefsKey::${entry.key}');
      } else {
        await prefs.setString('$_prefsKey::${entry.key}', entry.value.trim());
      }
    }
    setState(() => _isSaving = false);
    if (!mounted) return;
    Navigator.pop(context);
    showSuccessSnackBar(context, 'Prices saved successfully!');
  }

  List<CatalogItem> get _itemsForCategory => switch (_category) {
        'ppe' => ppeItems,
        'uniform' => uniformItems,
        _ => officeItems,
      };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(height: 4, width: 44, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Manage Item Prices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Set the purchase price for each item and size.', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
            const SizedBox(height: 14),
            Row(
              children: [
                for (final c in _categories)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: c == _categories.last ? 0 : 8),
                      child: OutlinedButton(
                        onPressed: () => setState(() => _category = c.$1),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _category == c.$1 ? AppColors.primary.withValues(alpha: 0.1) : null,
                          side: BorderSide(color: _category == c.$1 ? AppColors.primary : AppColors.border),
                          foregroundColor: _category == c.$1 ? AppColors.primary : AppColors.mutedForeground,
                        ),
                        child: Text(c.$2, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      children: [
                        for (final item in _itemsForCategory) _itemPriceCard(item),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const SizedBox() : const Icon(Icons.save_outlined, size: 16),
                label: Text(_isSaving ? 'Saving...' : 'Save Prices'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemPriceCard(CatalogItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          for (final size in item.sizes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(size.size, style: TextStyle(fontSize: 12, color: AppColors.mutedForeground))),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: TextEditingController(text: _overrides['${item.name}::${size.size}'] ?? size.price.toStringAsFixed(2))
                        ..selection = TextSelection.collapsed(offset: (_overrides['${item.name}::${size.size}'] ?? size.price.toStringAsFixed(2)).length),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(prefixText: 'RM ', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      onChanged: (v) => _overrides['${item.name}::${size.size}'] = v,
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
