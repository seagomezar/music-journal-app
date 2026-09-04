import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/piece.dart';
import '../models/repertoire_folder.dart';
import '../providers/repertoire_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/routine_provider.dart';
import '../theme/app_theme.dart';
import 'score_viewer_screen.dart';

class RepertoireView extends StatefulWidget {
  const RepertoireView({super.key});

  @override
  State<RepertoireView> createState() => _RepertoireViewState();
}

class _RepertoireViewState extends State<RepertoireView> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _bpmController = TextEditingController();
  final TextEditingController _measuresController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _selectedPdfPath;
  String? _selectedPdfName;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RepertoireProvider>(context, listen: false).loadPieces();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _bpmController.dispose();
    _measuresController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickPdf(
    BuildContext context,
    StateSetter setDialogState,
  ) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('pdf_web_unavailable'))),
      );
      return;
    }
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty) {
        setDialogState(() {
          _selectedPdfPath = result.files.first.path;
          _selectedPdfName = result.files.first.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('pdf_pick_error'))),
        );
      }
    }
  }

  void _showAddPieceDialog(BuildContext context) {
    _titleController.clear();
    _composerController.clear();
    _bpmController.text = '80';
    _measuresController.text = '100';
    _notesController.clear();
    _selectedPdfPath = null;
    _selectedPdfName = null;
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);
    var isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.translate('add_piece')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: context.translate('title_label'),
                        hintText: locProv.isSpanish
                            ? 'ej. Syrinx'
                            : 'e.g., Syrinx',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _composerController,
                      decoration: InputDecoration(
                        labelText: context.translate('composer_label'),
                        hintText: locProv.isSpanish
                            ? 'ej. Claude Debussy'
                            : 'e.g., Claude Debussy',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _bpmController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.translate('target_bpm_label'),
                              suffixText: 'BPM',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _measuresController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.translate('total_measures'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.translate('study_focus_notes'),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // PDF Picker area
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.borderColor(context),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              kIsWeb
                                  ? context.translate('pdf_web_unavailable')
                                  : _selectedPdfName ??
                                        context.translate('no_pdf_attached'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedPdfName != null
                                    ? AppTheme.textPrimaryColor(context)
                                    : AppTheme.textSecondaryColor(context),
                              ),
                            ),
                          ),
                          if (!kIsWeb)
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () => _pickPdf(context, setDialogState),
                              child: Text(
                                _selectedPdfName != null
                                    ? context.translate('change_btn')
                                    : context.translate('browse_btn'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    context.translate('cancel'),
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor(context),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final title = _titleController.text.trim();
                          final targetBpm = int.tryParse(_bpmController.text);
                          final totalMeasures = int.tryParse(
                            _measuresController.text,
                          );
                          final isValid =
                              title.isNotEmpty &&
                              title.length <= 100 &&
                              targetBpm != null &&
                              targetBpm >= 30 &&
                              targetBpm <= 252 &&
                              totalMeasures != null &&
                              totalMeasures >= 0 &&
                              totalMeasures <= 10000 &&
                              (_selectedPdfName == null ||
                                  _selectedPdfPath != null);
                          if (!isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.translate('invalid_piece_values'),
                                ),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final piece = Piece(
                            id: 'piece_${const Uuid().v7()}',
                            title: title,
                            composer: _composerController.text.trim().isEmpty
                                ? 'Unknown'
                                : _composerController.text.trim(),
                            targetBpm: targetBpm,
                            measuresTotal: totalMeasures,
                            measuresCompleted: 0,
                            pdfPath: _selectedPdfPath,
                            notes: _notesController.text.trim(),
                            folderId: _selectedFolderId,
                          );
                          try {
                            await Provider.of<RepertoireProvider>(
                              context,
                              listen: false,
                            ).savePiece(
                              piece,
                              pdfOriginalName: _selectedPdfName,
                            );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (error) {
                            if (!context.mounted) return;
                            setDialogState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.translate('piece_save_error'),
                                ),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.translate('add_btn')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPieceDetailsDialog(
    BuildContext context,
    Piece piece,
    RepertoireProvider provider,
  ) {
    int localCompleted = piece.measuresCompleted
        .clamp(0, piece.measuresTotal)
        .toInt();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final progress = piece.measuresTotal > 0
                ? (localCompleted / piece.measuresTotal).clamp(0.0, 1.0)
                : 0.0;
            return AlertDialog(
              title: Text(
                piece.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.translate('composer_format', [
                        piece.composer == 'Unknown'
                            ? context.translate('unknown')
                            : piece.composer,
                      ]),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.translate('target_tempo_format', [
                        piece.targetBpm.toString(),
                      ]),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    if (piece.pdfPath != null) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.insert_drive_file_outlined,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.translate('score_sheet_format', [
                                piece.pdfPath!.split(RegExp(r'[\\/]')).last,
                              ]),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor(context),
                          side: BorderSide(
                            color: AppTheme.primaryColor(context),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          context.translate('view_score_btn'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ScoreViewerScreen(
                                pieceId: piece.id,
                                pdfPath: piece.pdfPath!,
                                pieceTitle: piece.title,
                                pieceBpm: piece.targetBpm,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    Divider(height: 24, color: AppTheme.borderColor(context)),

                    // Progress Slider
                    Text(
                      context.translate('measures_progress_format', [
                        localCompleted.toString(),
                        piece.measuresTotal.toString(),
                      ]),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.borderColor(context),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.secondaryColor(context),
                        ),
                      ),
                    ),
                    if (piece.measuresTotal > 0) ...[
                      Slider(
                        min: 0,
                        max: piece.measuresTotal.toDouble(),
                        activeColor: AppTheme.secondaryColor(context),
                        inactiveColor: AppTheme.borderColor(context),
                        value: localCompleted.toDouble(),
                        onChanged: (double val) {
                          setDialogState(() {
                            localCompleted = val.round();
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 12),
                    Text(
                      context.translate('focus_notes_label'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      piece.notes.isEmpty
                          ? context.translate('no_focus_notes')
                          : piece.notes,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                  tooltip: context.translate('delete_btn'),
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (confirmContext) => AlertDialog(
                        title: Text(
                          confirmContext.translate('delete_piece_title'),
                        ),
                        content: Text(
                          confirmContext.translate('delete_piece_confirm'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(confirmContext).pop(false),
                            child: Text(confirmContext.translate('cancel')),
                          ),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(confirmContext).pop(true),
                            child: Text(confirmContext.translate('delete_btn')),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await provider.deletePiece(piece.id);
                      if (context.mounted) {
                        await context.read<RoutineProvider>().loadRoutines();
                      }
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.translate('piece_delete_error'),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.drive_file_move_outline, size: 18),
                  label: Text(context.translate('move_piece')),
                  onPressed: () async {
                    final moved = await _showMovePieceDialog(
                      context,
                      piece,
                      provider,
                    );
                    if (moved && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.translate('cancel'),
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor(context),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    try {
                      await provider.updatePieceProgress(
                        piece.id,
                        localCompleted,
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.translate('piece_save_error'),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(context.translate('save_progress_btn')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showFolderNameDialog(
    BuildContext context,
    RepertoireProvider provider, {
    RepertoireFolder? folder,
  }) async {
    var folderName = folder?.name ?? '';
    String? errorText;
    var isSaving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            dialogContext.translate(
              folder == null ? 'create_folder' : 'rename_folder',
            ),
          ),
          content: TextFormField(
            initialValue: folderName,
            autofocus: true,
            enabled: !isSaving,
            maxLength: 100,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: dialogContext.translate('folder_name'),
              errorText: errorText,
            ),
            onChanged: (value) => folderName = value,
            onFieldSubmitted: isSaving
                ? null
                : (_) => _saveFolderName(
                    dialogContext,
                    provider,
                    folderName,
                    folder: folder,
                    setDialogState: setDialogState,
                    setSaving: (value) => isSaving = value,
                    setError: (value) => errorText = value,
                  ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.translate('cancel')),
            ),
            FilledButton(
              onPressed: isSaving
                  ? null
                  : () => _saveFolderName(
                      dialogContext,
                      provider,
                      folderName,
                      folder: folder,
                      setDialogState: setDialogState,
                      setSaving: (value) => isSaving = value,
                      setError: (value) => errorText = value,
                    ),
              child: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      dialogContext.translate(
                        folder == null ? 'create_btn' : 'rename_btn',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveFolderName(
    BuildContext dialogContext,
    RepertoireProvider provider,
    String value, {
    required RepertoireFolder? folder,
    required StateSetter setDialogState,
    required ValueChanged<bool> setSaving,
    required ValueChanged<String?> setError,
  }) async {
    final name = value.trim();
    String? validationError;
    if (name.isEmpty || name.length > 100) {
      validationError = dialogContext.translate('invalid_folder_name');
    } else if (provider.folders.any(
      (existing) =>
          existing.id != folder?.id &&
          existing.name.toLowerCase() == name.toLowerCase(),
    )) {
      validationError = dialogContext.translate('duplicate_folder_name');
    }
    if (validationError != null) {
      setDialogState(() => setError(validationError));
      return;
    }

    setDialogState(() {
      setError(null);
      setSaving(true);
    });
    try {
      if (folder == null) {
        await provider.createFolder(name);
      } else {
        await provider.renameFolder(folder.id, name);
      }
      if (dialogContext.mounted) Navigator.of(dialogContext).pop();
    } catch (_) {
      if (!dialogContext.mounted) return;
      setDialogState(() => setSaving(false));
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text(dialogContext.translate('folder_save_error'))),
      );
    }
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    RepertoireFolder folder,
    RepertoireProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.translate('delete_folder_title')),
        content: Text(dialogContext.translate('delete_folder_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.translate('delete_btn')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await provider.deleteFolder(folder.id);
      if (_selectedFolderId == folder.id && mounted) {
        setState(() => _selectedFolderId = null);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('folder_delete_error'))),
      );
    }
  }

  Future<bool> _showMovePieceDialog(
    BuildContext context,
    Piece piece,
    RepertoireProvider provider,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            var isMoving = false;
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                Future<void> move(String? folderId) async {
                  if (isMoving) return;
                  if (folderId == piece.folderId) {
                    Navigator.of(dialogContext).pop(false);
                    return;
                  }
                  setDialogState(() => isMoving = true);
                  try {
                    await provider.movePiece(piece.id, folderId);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  } catch (_) {
                    if (!dialogContext.mounted) return;
                    setDialogState(() => isMoving = false);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          dialogContext.translate('piece_move_error'),
                        ),
                      ),
                    );
                  }
                }

                return AlertDialog(
                  title: Text(dialogContext.translate('move_piece')),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        ListTile(
                          enabled: !isMoving,
                          leading: const Icon(Icons.folder_off_outlined),
                          title: Text(dialogContext.translate('unfiled')),
                          trailing: piece.folderId == null
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: () => move(null),
                        ),
                        ...provider.folders.map(
                          (folder) => ListTile(
                            enabled: !isMoving,
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(folder.name),
                            trailing: piece.folderId == folder.id
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: () => move(folder.id),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isMoving
                          ? null
                          : () => Navigator.of(dialogContext).pop(false),
                      child: Text(dialogContext.translate('cancel')),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Widget _buildFolderCard(
    BuildContext context,
    RepertoireFolder folder,
    RepertoireProvider provider,
  ) {
    final count = provider.pieceCountForFolder(folder.id);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedFolderId = folder.id),
      child: AppTheme.glassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.folder_rounded,
              size: 42,
              color: AppTheme.accentColor(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.translate('folder_piece_count', [count.toString()]),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: context.translate('folder_actions'),
              onSelected: (action) {
                if (action == 'rename') {
                  _showFolderNameDialog(context, provider, folder: folder);
                } else if (action == 'delete') {
                  _confirmDeleteFolder(context, folder, provider);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(context.translate('rename_folder')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.translate('delete_folder')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieceCard(
    BuildContext context,
    Piece piece,
    RepertoireProvider provider,
  ) {
    return GestureDetector(
      onTap: () => _showPieceDetailsDialog(context, piece, provider),
      child: AppTheme.glassCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(top: 8),
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: piece.progressPercentage,
                          strokeWidth: 5,
                          backgroundColor: AppTheme.borderColor(
                            context,
                          ).withValues(alpha: 0.5),
                          color: AppTheme.secondaryColor(context),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${(piece.progressPercentage * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Text(
              piece.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'serif',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              piece.composer == 'Unknown'
                  ? context.translate('unknown')
                  : piece.composer,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.translate('meas_count_format', [
                    piece.measuresCompleted.toString(),
                    piece.measuresTotal.toString(),
                  ]),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondaryColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${piece.targetBpm} BPM',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppTheme.accentColor(context),
                      fontWeight: FontWeight.bold,
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

  Widget _buildEmptyState(BuildContext context, {required bool folder}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              folder ? Icons.folder_open_rounded : Icons.library_music_rounded,
              size: 72,
              color: AppTheme.borderColor(context).withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.translate(
                folder ? 'folder_empty_title' : 'repertoire_empty_title',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              context.translate(
                folder ? 'folder_empty_desc' : 'repertoire_empty_desc',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryColor(context)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repProv = Provider.of<RepertoireProvider>(context);
    RepertoireFolder? selectedFolder;
    for (final folder in repProv.folders) {
      if (folder.id == _selectedFolderId) {
        selectedFolder = folder;
        break;
      }
    }
    final visiblePieces = _selectedFolderId == null
        ? repProv.piecesInFolder(null)
        : selectedFolder == null
        ? const <Piece>[]
        : repProv.piecesInFolder(selectedFolder.id);

    return Scaffold(
      appBar: AppBar(
        leading: selectedFolder == null
            ? null
            : IconButton(
                tooltip: context.translate('back_to_repertoire'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _selectedFolderId = null),
              ),
        title: Text(
          selectedFolder?.name ?? context.translate('repertoire_manager_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (selectedFolder == null)
            IconButton(
              tooltip: context.translate('create_folder'),
              icon: Icon(
                Icons.create_new_folder_outlined,
                color: AppTheme.accentColor(context),
              ),
              onPressed: () => _showFolderNameDialog(context, repProv),
            ),
          IconButton(
            tooltip: context.translate('add_piece'),
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.accentColor(context),
              size: 28,
            ),
            onPressed: () => _showAddPieceDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: repProv.isLoading
            ? const Center(child: CircularProgressIndicator())
            : selectedFolder != null && visiblePieces.isEmpty
            ? _buildEmptyState(context, folder: true)
            : repProv.pieces.isEmpty && repProv.folders.isEmpty
            ? _buildEmptyState(context, folder: false)
            : Column(
                children: [
                  if (selectedFolder == null && repProv.folders.isNotEmpty)
                    SizedBox(
                      height: 124,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        scrollDirection: Axis.horizontal,
                        itemCount: repProv.folders.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => SizedBox(
                          width: 290,
                          child: _buildFolderCard(
                            context,
                            repProv.folders[index],
                            repProv,
                          ),
                        ),
                      ),
                    ),
                  if (selectedFolder == null && visiblePieces.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          context.translate('unfiled'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  Expanded(
                    child: visiblePieces.isEmpty
                        ? const SizedBox.shrink()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 960
                                  ? 4
                                  : constraints.maxWidth >= 640
                                  ? 3
                                  : 2;
                              return GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 14,
                                      mainAxisSpacing: 14,
                                      childAspectRatio: columns >= 3
                                          ? 0.9
                                          : 0.78,
                                    ),
                                itemCount: visiblePieces.length,
                                itemBuilder: (context, index) {
                                  return _buildPieceCard(
                                    context,
                                    visiblePieces[index],
                                    repProv,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}
