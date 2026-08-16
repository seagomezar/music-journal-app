import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/piece.dart';
import '../providers/repertoire_provider.dart';
import '../providers/localization_provider.dart';
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
                              targetBpm >= 40 &&
                              targetBpm <= 240 &&
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

  @override
  Widget build(BuildContext context) {
    final repProv = Provider.of<RepertoireProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate('repertoire_manager_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
            : repProv.pieces.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.library_music_rounded,
                        size: 72,
                        color: AppTheme.borderColor(
                          context,
                        ).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.translate('repertoire_empty_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('repertoire_empty_desc'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 960
                      ? 4
                      : constraints.maxWidth >= 640
                      ? 3
                      : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: columns >= 3 ? 0.9 : 0.78,
                    ),
                    itemCount: repProv.pieces.length,
                    itemBuilder: (context, index) {
                      final piece = repProv.pieces[index];
                      return GestureDetector(
                        onTap: () =>
                            _showPieceDetailsDialog(context, piece, repProv),
                        child: AppTheme.glassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Circular Progress Ring Indicator
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
                                            backgroundColor:
                                                AppTheme.borderColor(
                                                  context,
                                                ).withValues(alpha: 0.5),
                                            color: AppTheme.secondaryColor(
                                              context,
                                            ),
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

                              // Title & Composer
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

                              // Measures bar count
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.translate('meas_count_format', [
                                      piece.measuresCompleted.toString(),
                                      piece.measuresTotal.toString(),
                                    ]),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textSecondaryColor(
                                        context,
                                      ),
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
                    },
                  );
                },
              ),
      ),
    );
  }
}
