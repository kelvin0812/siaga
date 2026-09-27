import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/command_background.dart';
import '../widgets/glass_card.dart';

/// Section 6.4: one-tap community hazard report. Submits cell_id (never
/// coordinates — Section 3.1/5.3), category, and an optional note.
///
/// The "where did you notice this" field is free text the user chooses
/// to type, not device location — it's folded into the submitted note
/// (Section 5.3's ReportIn has no separate field for it) so the payload
/// stays within the fixed API surface rather than inventing a new one.
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
  final _whereController = TextEditingController();
  final _noteController = TextEditingController();
  bool _submitting = false;
  String? _resultMessage;
  bool _resultIsError = false;

  @override
  void dispose() {
    _whereController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _categoryApiValue(_ReportCategory c) => switch (c) {
        _ReportCategory.flooding => 'flooding',
        _ReportCategory.landslide => 'landslide',
        _ReportCategory.other => 'other',
      };

  String? _combinedNote(AppLocalizations l10n) {
    final where = _whereController.text.trim();
    final note = _noteController.text.trim();
    if (where.isEmpty && note.isEmpty) return null;
    if (where.isEmpty) return note;
    final wherePart = '${l10n.reportWherePrefix}: $where';
    if (note.isEmpty) return wherePart;
    return '$wherePart\n\n$note';
  }

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
        note: _combinedNote(l10n),
      );
      if (!mounted) return;
      setState(() {
        _resultMessage = l10n.reportSubmitted;
        _resultIsError = false;
        _whereController.clear();
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

  IconData _categoryIcon(_ReportCategory c) => switch (c) {
        _ReportCategory.flooding => Icons.water_drop_outlined,
        _ReportCategory.landslide => Icons.terrain_outlined,
        _ReportCategory.other => Icons.report_gmailerrorred_outlined,
      };

  String _categoryLabel(AppLocalizations l10n, _ReportCategory c) => switch (c) {
        _ReportCategory.flooding => l10n.reportCategoryFlooding,
        _ReportCategory.landslide => l10n.reportCategoryLandslide,
        _ReportCategory.other => l10n.reportCategoryOther,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CommandBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.reportTitle, style: AppFonts.heading(fontSize: 26)),
                  const SizedBox(height: 20),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.reportSectionDetails.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.reportCategoryLabel,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _ReportCategory.values.map((c) {
                            final selected = c == _category;
                            return _CategoryChip(
                              icon: _categoryIcon(c),
                              label: _categoryLabel(l10n, c),
                              selected: selected,
                              onTap: () => setState(() => _category = c),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),
                        _GlowField(
                          child: TextField(
                            controller: _whereController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              labelText: l10n.reportWhereLabel,
                              hintText: l10n.reportWhereHint,
                              prefixIcon: const Icon(Icons.place_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _GlowField(
                          child: TextField(
                            controller: _noteController,
                            style: const TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(labelText: l10n.reportNoteLabel),
                            maxLines: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SubmitButton(
                    submitting: _submitting,
                    label: l10n.reportSubmit,
                    onPressed: _submitting ? null : _submit,
                  ),
                  if (_resultMessage != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(
                          _resultIsError ? Icons.error_outline : Icons.check_circle_outline,
                          size: 16,
                          color: _resultIsError ? AppColors.evacuate : AppColors.normal,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _resultMessage!,
                            style: TextStyle(color: _resultIsError ? AppColors.evacuate : AppColors.normal),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a field with a soft glow that appears on focus — the "glowing
/// focus ring" in place of Material's flat 1.5px accent outline.
class _GlowField extends StatefulWidget {
  final Widget child;
  const _GlowField({required this.child});

  @override
  State<_GlowField> createState() => _GlowFieldState();
}

class _GlowFieldState extends State<_GlowField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: _focused ? appGlow(AppColors.accent, alpha: 0.3, blur: 18) : null,
        ),
        child: widget.child,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inner = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(horizontal: selected ? 15 : 16, vertical: selected ? 9 : 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: selected ? null : Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: selected ? AppColors.accent : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: selected
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF6D5DF6)]),
                boxShadow: appGlow(AppColors.accent, alpha: 0.4, blur: 14),
              ),
              child: inner,
            )
          : inner,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool submitting;
  final String label;
  final VoidCallback? onPressed;

  const _SubmitButton({required this.submitting, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        gradient: const LinearGradient(colors: [AppColors.accent, Color(0xFF6D5DF6)]),
        boxShadow: onPressed != null ? appGlow(AppColors.accent, alpha: 0.35, blur: 22) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: Center(
            child: submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
