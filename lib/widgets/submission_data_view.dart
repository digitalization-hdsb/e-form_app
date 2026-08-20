import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';

const Set<String> _hiddenDataKeys = {
  'refNo',
  'lastUpdatedAt',
  'approvalRemarksHistory',
  'remarks',
  'finance_admin_remarks',
  'rejectedStage',
  'rejectedFromStatus',
  // The submitter's profile photo, carried along purely so admin list rows
  // can show it as an avatar — never useful as raw dumped text.
  'avatar',
  // Approver names already surfaced by ApprovalStages at the bottom of the
  // detail sheet — repeating them here as raw rows would just duplicate
  // (and, before this widget knew about attachments/objects, badly format)
  // the same information.
  'hos',
  'hod',
  'hosName',
  'hodName',
  'hopName',
  'hofName',
  'mancoMemberName',
  'financeReviewedByName',
  'financePaidByName',
  'hrAdminReviewedByName',
  'itAdminReviewedBy',
  'securityExitReviewedByName',
  'securityEntryReviewedByName',
  'securityReviewedByName',
  'resolvedBy',
  'lastEditedBy',
  // The server-side "when did security click the button" bookkeeping —
  // securityLog.actualTimeOut/actualTimeIn (guard-entered, shown below via
  // _keyLabelOverrides as "Time Out"/"Time In") is the meaningful time.
  'securityExitReviewedAt',
  'securityEntryReviewedAt',
};

/// Raw internal ids (hosUserId, financePaidById, ...) are never meant for
/// display — the human-readable `*Name` counterpart is what's shown, either
/// in [EmployeeInfoCard] or [ApprovalStages].
bool _isInternalIdKey(String key) => key.endsWith('Id');

/// Detects `DateTime.now().toIso8601String()`-shaped values (every
/// `*At`/`*By...At` bookkeeping field in the app is written this way) so
/// they render as a readable date instead of a raw ISO string.
bool _looksLikeIsoDate(String value) => value.contains('T') && DateTime.tryParse(value) != null;

String _formatIsoDate(String value) => DateFormat('d MMM yyyy, h:mm a').format(DateTime.parse(value).toLocal());

/// Special-cased labels/link text, mirroring the `formattedKey` overrides
/// in AdminDashboard.tsx / AllSubmissionsPage.tsx.
const Map<String, String> _keyLabelOverrides = {
  'licenseAttachment': 'Driving Licence',
  'companyDetails': 'Company Details',
  'personalDetails': 'Personal Details',
  'purposeType': 'Purpose Type',
  'securityLog': 'Gate Log',
  'actualTimeOut': 'Time Out',
  'actualTimeIn': 'Time In',
};

/// Column order for row-shaped list values that have these exact keys,
/// mirroring the claim-form column enforcement in AdminDashboard.tsx.
const List<String> _claimRowKeyOrder = ['description', 'receiptNo', 'amount'];

String labelizeKey(String key) {
  final override = _keyLabelOverrides[key];
  if (override != null) return override;
  final spaced = key.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');
  final withSpaces = spaced.replaceAll('_', ' ');
  return withSpaces.isEmpty ? withSpaces : withSpaces[0].toUpperCase() + withSpaces.substring(1);
}

bool _isUrl(dynamic value) => value is String && (value.startsWith('http://') || value.startsWith('https://'));

String stringifyValue(dynamic value) {
  if (value == null) return '—';
  if (value is List) {
    if (value.isEmpty) return '—';
    if (value.every((e) => e is Map)) return value.map((e) => (e as Map).values.join(' · ')).join('\n');
    return value.join(', ');
  }
  if (value is Map) return value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
  return value.toString();
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the attachment.')));
  }
}

class _AttachmentLink extends StatelessWidget {
  final String url;
  final String label;

  const _AttachmentLink({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openUrl(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary, decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }
}

/// A small bordered table for list-of-object values (passengers, claim
/// rows, checklist items, ...), mirroring the `renderValue` table in
/// AdminDashboard.tsx instead of squashing rows into one line of text.
class _ObjectListTable extends StatelessWidget {
  final List<Map> rows;

  const _ObjectListTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final validRows = rows.where((r) => r.values.any((v) => v != null && v.toString().isNotEmpty)).toList();
    if (validRows.isEmpty) return Text('—', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.foreground));

    var keys = validRows.first.keys.where((k) => k != 'avatar').map((k) => k.toString()).toList();
    if (_claimRowKeyOrder.every(keys.contains)) keys = _claimRowKeyOrder;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
        child: DataTable(
          headingRowHeight: 34,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          columnSpacing: 20,
          horizontalMargin: 12,
          headingTextStyle: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3),
          dataTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.foreground),
          columns: [for (final k in keys) DataColumn(label: Text(labelizeKey(k).toUpperCase()))],
          rows: [
            for (final row in validRows)
              DataRow(cells: [
                for (final k in keys) DataCell(Text(row[k] == null || row[k].toString().isEmpty ? '—' : row[k].toString())),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Two tappable attachment links per row, to use horizontal space instead
/// of stacking every attachment on its own line.
Widget _attachmentLinkGrid(List<String> urls, {String Function(int index)? labelFor}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 12) / 2;
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (var i = 0; i < urls.length; i++)
            SizedBox(width: itemWidth, child: _AttachmentLink(url: urls[i], label: labelFor?.call(i) ?? 'Attachment ${i + 1}')),
        ],
      );
    },
  );
}

/// The claim rows table plus its right-aligned, larger-font total —
/// mirroring the "Claim Details" block in MySubmissions.tsx / FinanceDashboard.tsx,
/// where the total sits directly under the table instead of as just another
/// generic key/value row.
class _ClaimRowsSection extends StatelessWidget {
  final List<Map> rows;
  final dynamic totalAmount;

  const _ClaimRowsSection({required this.rows, this.totalAmount});

  @override
  Widget build(BuildContext context) {
    final amount = totalAmount is num ? (totalAmount as num).toDouble() : double.tryParse(totalAmount?.toString() ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Claim Details', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.2)),
        const SizedBox(height: 6),
        _ObjectListTable(rows: rows),
        if (amount != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('TOTAL AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.4)),
                const SizedBox(height: 2),
                Text('RM ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// A bordered key/value card for nested object values (employeeInfo,
/// companyDetails, estimatedTime, ...), mirroring the object grid in
/// AdminDashboard.tsx `renderValue` instead of a single comma-joined line.
class _ObjectCard extends StatelessWidget {
  final Map map;

  const _ObjectCard({required this.map});

  @override
  Widget build(BuildContext context) {
    final entries = map.entries.where((e) => e.key != 'avatar' && e.value != null && e.value.toString().isNotEmpty).toList();
    if (entries.isEmpty) return Text('—', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.foreground));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        children: [
          for (final e in entries)
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(labelizeKey(e.key.toString()).toUpperCase(), style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.mutedForeground, letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(
                    _isUrl(e.value)
                        ? ''
                        : (e.value is String && _looksLikeIsoDate(e.value as String))
                            ? _formatIsoDate(e.value as String)
                            : e.value.toString(),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  if (_isUrl(e.value)) _AttachmentLink(url: e.value as String, label: 'View ${labelizeKey(e.key.toString())}'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Generic key/value dump of a submission's `data` blob — used as the base
/// layer beneath formType-specific highlighted fields in every dashboard.
/// Renders attachments as tappable links, list-of-object values (passengers,
/// claim rows) as a real table, and nested objects as a labeled card,
/// instead of flattening everything into one line of raw text.
class SubmissionDataView extends StatelessWidget {
  final Map<String, dynamic> data;
  final Set<String> extraHiddenKeys;

  const SubmissionDataView({super.key, required this.data, this.extraHiddenKeys = const {}});

  /// `attachments` (list) and its legacy singular `attachment` fallback
  /// always describe the same files (mirrors how every form's submit
  /// handler writes `attachment: urls[0], attachments: urls`), so they're
  /// merged into one "Attachments" section instead of showing twice.
  List<String> _mergedAttachmentUrls() {
    final list = data['attachments'];
    if (list is List) {
      final urls = list.whereType<String>().where(_isUrl).toList();
      if (urls.isNotEmpty) return urls;
    }
    final single = data['attachment'];
    return (single is String && _isUrl(single)) ? [single] : const [];
  }

  @override
  Widget build(BuildContext context) {
    final hasClaimRows = data['claimRows'] is List && (data['claimRows'] as List).isNotEmpty;
    final attachmentUrls = _mergedAttachmentUrls();

    final entries = data.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty && !_hiddenDataKeys.contains(e.key) && !extraHiddenKeys.contains(e.key))
        .where((e) => !_isInternalIdKey(e.key))
        .where((e) => e.key != 'attachment' && e.key != 'attachments')
        .where((e) => !(e.key == 'totalAmount' && hasClaimRows))
        .where((e) => e.value is! List || (e.value as List).isNotEmpty)
        .where((e) => e.value is! Map || (e.value as Map).isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in entries) _row(entry.key, entry.value),
        if (attachmentUrls.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attachments', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.2)),
                const SizedBox(height: 6),
                _attachmentLinkGrid(attachmentUrls),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(String key, dynamic value) {
    if (key == 'claimRows' && value is List && value.isNotEmpty && value.every((e) => e is Map)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _ClaimRowsSection(rows: value.cast<Map>(), totalAmount: data['totalAmount']),
      );
    }

    final isBlock = value is Map || (value is List && value.isNotEmpty && (value.first is Map || _isUrl(value.first)));

    final Widget valueWidget;
    if (value is Map) {
      valueWidget = _ObjectCard(map: value);
    } else if (value is List && value.isNotEmpty && value.every((e) => e is Map)) {
      valueWidget = _ObjectListTable(rows: value.cast<Map>());
    } else if (_isUrl(value)) {
      valueWidget = _AttachmentLink(url: value as String, label: 'View ${labelizeKey(key)}');
    } else if (value is List && value.isNotEmpty && value.every(_isUrl)) {
      valueWidget = _attachmentLinkGrid(value.cast<String>());
    } else if (value is String && _looksLikeIsoDate(value)) {
      valueWidget = Text(_formatIsoDate(value), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600));
    } else {
      valueWidget = Text(stringifyValue(value), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isBlock
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(labelizeKey(key), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.2)),
                const SizedBox(height: 6),
                valueWidget,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 130, child: Text(labelizeKey(key), style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground))),
                Expanded(child: valueWidget),
              ],
            ),
    );
  }
}
