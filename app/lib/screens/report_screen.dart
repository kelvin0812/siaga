import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_state.dart';
import '../l10n/app_localizations.dart';

/// Section 6.4: one-tap community hazard report. Submits cell_id (never
/// coordinates — Section 3.1/5.3), category, and an optional note.
///
/// Photo attachment is NOT implemented here: Section 5.3's ReportIn model
/// accepts a photo_url on the assumption a photo is uploaded "somewhere"
/// first, but nothing in the brief specifies an object-storage backend
/// for it, and none exists yet in this project (no Supabase Storage
/// bucket, no upload endpoint). Building a picker with nowhere to send
/// the file would be a half-finished feature; deferred and flagged in
/// docs/nexus-log.md pending that decision.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum _ReportCategory { flooding, landslide, other }

class _ReportScreenState extends State<ReportScreen> {
  _ReportCategory _category = _ReportCategory.flooding;
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _categoryApiValue(_ReportCategory c) => switch (c) {
        _ReportCategory.flooding => 'flooding',
        _ReportCategory.landslide => 'landslide',
        _ReportCategory.other => 'other',
      };

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    final cellId = appState.currentCellId;
    if (cellId == null) {
      setState(() {
        _resultMessage = l10n.myRiskNoCell;
        _resultIsError = true;
      });
      return;
    }

    setState(() {
      _submitting = true;
      _resultMessage = null;
    });

    try {
      await appState.api.submitReport(
        cellId: cellId,
        category: _categoryApiValue(_category),
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resultMessage = l10n.reportSubmitted;
        _resultIsError = false;
        _noteController.clear();
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _resultMessage = l10n.reportFailed;
        _resultIsError = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reportTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _CategoryOption(
              label: l10n.reportCategoryFlooding,
              value: _ReportCategory.flooding,
              groupValue: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
            _CategoryOption(
              label: l10n.reportCategoryLandslide,
              value: _ReportCategory.landslide,
              groupValue: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
            _CategoryOption(
              label: l10n.reportCategoryOther,
              value: _ReportCategory.other,
              groupValue: _category,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.reportNoteLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(l10n.reportSubmit),
            ),
            if (_resultMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _resultMessage!,
                style: TextStyle(color: _resultIsError ? Colors.red : Colors.green),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  final String label;
  final _ReportCategory value;
  final _ReportCategory groupValue;
  final ValueChanged<_ReportCategory> onChanged;

  const _CategoryOption({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<_ReportCategory>(
      title: Text(label),
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      // ignore: deprecated_member_use
      onChanged: (v) => onChanged(v!),
      contentPadding: EdgeInsets.zero,
    );
  }
}
