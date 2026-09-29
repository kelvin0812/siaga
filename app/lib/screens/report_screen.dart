import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/api_client.dart';
import '../core/app_state.dart';
import '../core/photo_upload_service.dart';
import '../core/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/command_background.dart';
import '../widgets/glass_card.dart';

/// Section 6.4: one-tap community hazard report. Submits cell_id (never
/// coordinates — Section 3.1/5.3), category, and an optional note.
///
/// Mentor-review redesign: category and location are now dropdown boxes
/// rather than a chip row + free-text field, and a photo can be attached.
/// "Location" picks between the reporter's own GPS-derived cell (default,
/// same privacy path as before) or a specific monitored node's cell — a
/// report is about a hazard sighting, not necessarily standing exactly at
/// the reporter's own position, and either way the payload only ever
/// carries an H3 cell id, never coordinates.
///
/// The photo is uploaded directly from the device to Supabase Storage
/// (see photo_upload_service.dart) before submitReport() is called with
/// the resulting URL — this API stays a small JSON body per Section 5.3.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

enum _ReportCategory { flooding, landslide, other }

class _ReportScreenState extends State<ReportScreen> {
  _ReportCategory _category = _ReportCategory.flooding;
  int? _locationNodeId; // null = reporter's own current location
  final _noteController = TextEditingController();
  bool _submitting = false;
  bool _uploadingPhoto = false;
  String? _resultMessage;
  bool _resultIsError = false;

  final _photoUploader = PhotoUploadService();
  final _imagePicker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoContentType;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext = file.name.toLowerCase();
    final contentType = ext.endsWith('.png')
        ? 'image/png'
        : ext.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    setState(() {
      _photoBytes = bytes;
      _photoContentType = contentType;
    });
  }

  void _removePhoto() {
    setState(() {
      _photoBytes = null;
      _photoContentType = null;
    });
  }

  String _categoryApiValue(_ReportCategory c) => switch (c) {
        _ReportCategory.flooding => 'flooding',
        _ReportCategory.landslide => 'landslide',
        _ReportCategory.other => 'other',
      };

  String? _combinedNote() {
    final note = _noteController.text.trim();
    return note.isEmpty ? null : note;
  }

  /// Resolves the report's cell_id: either the reporter's own GPS-derived
  /// cell (default), or — if a specific node was picked from the location
  /// dropdown — that node's own fixed-position cell, computed the same way
  /// LocationService computes the device's own (Section 3.1: an H3 cell
  /// derived from a known public node position isn't a privacy concern the
  /// way raw device coordinates would be).
  String? _resolveCellId(AppState appState) {
    if (_locationNodeId == null) return appState.currentCellId;
    final node = appState.nodes.where((n) => n.id == _locationNodeId).firstOrNull;
    if (node == null) return appState.currentCellId;
    return appState.locationService.cellForCoordinates(node.lat, node.lon);
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();
    final cellId = _resolveCellId(appState);
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
      String? photoUrl;
      if (_photoBytes != null) {
        setState(() => _uploadingPhoto = true);
        try {
          photoUrl = await _photoUploader.upload(_photoBytes!, contentType: _photoContentType ?? 'image/jpeg');
        } on PhotoUploadException {
          if (!mounted) return;
          setState(() {
            _resultMessage = l10n.reportPhotoUploadFailed;
            _resultIsError = true;
            _uploadingPhoto = false;
            _submitting = false;
          });
          return;
        }
        if (mounted) setState(() => _uploadingPhoto = false);
      }

      await appState.api.submitReport(
        cellId: cellId,
        category: _categoryApiValue(_category),
        note: _combinedNote(),
        photoUrl: photoUrl,
      );
      if (!mounted) return;
      setState(() {
        _resultMessage = l10n.reportSubmitted;
        _resultIsError = false;
        _noteController.clear();
        _photoBytes = null;
        _photoContentType = null;
        _locationNodeId = null;
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
    final appState = context.watch<AppState>();
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
                        _GlowField(
                          child: DropdownButtonFormField<_ReportCategory>(
                            initialValue: _category,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                            dropdownColor: AppColors.surfaceRaised,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
                            items: _ReportCategory.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_categoryIcon(c), size: 18, color: AppColors.accent),
                                        const SizedBox(width: 10),
                                        Text(_categoryLabel(l10n, c)),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (c) {
                              if (c != null) setState(() => _category = c);
                            },
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          l10n.reportLocationLabel,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _GlowField(
                          child: DropdownButtonFormField<int?>(
                            initialValue: _locationNodeId,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                            dropdownColor: AppColors.surfaceRaised,
                            decoration: const InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.my_location, size: 16, color: AppColors.accent),
                                    const SizedBox(width: 10),
                                    Text(l10n.reportLocationCurrent),
                                  ],
                                ),
                              ),
                              ...appState.nodes.map(
                                (n) => DropdownMenuItem<int?>(
                                  value: n.id,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.sensors, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 10),
                                      Flexible(child: Text(n.name, overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (id) => setState(() => _locationNodeId = id),
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
                        const SizedBox(height: 18),
                        Text(
                          l10n.reportAddPhoto,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        _PhotoPicker(
                          bytes: _photoBytes,
                          uploading: _uploadingPhoto,
                          onPick: _pickPhoto,
                          onRemove: _removePhoto,
                          addLabel: l10n.reportAddPhoto,
                          removeLabel: l10n.reportPhotoRemove,
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

/// Pick/preview/remove a single report photo. Uploading happens later, at
/// submit time (_ReportScreenState._submit) — this widget only ever holds
/// local bytes, never a URL, so there's nothing to clean up if the user
/// removes the photo before submitting.
class _PhotoPicker extends StatelessWidget {
  final Uint8List? bytes;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final String addLabel;
  final String removeLabel;

  const _PhotoPicker({
    required this.bytes,
    required this.uploading,
    required this.onPick,
    required this.onRemove,
    required this.addLabel,
    required this.removeLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (bytes == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline, style: BorderStyle.solid),
            color: Colors.white.withValues(alpha: 0.03),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary, size: 22),
              const SizedBox(height: 8),
              Text(addLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Stack(
        children: [
          Image.memory(bytes!, width: double.infinity, height: 160, fit: BoxFit.cover),
          if (uploading)
            Container(
              width: double.infinity,
              height: 160,
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.6),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: removeLabel,
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: uploading ? null : onRemove,
              ),
            ),
          ),
        ],
      ),
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
