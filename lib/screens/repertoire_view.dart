import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/piece.dart';
import '../providers/repertoire_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';

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

  Future<void> _pickPdf(StateSetter setDialogState) async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
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
                        hintText: locProv.isSpanish ? 'ej. Syrinx' : 'e.g., Syrinx',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _composerController,
                      decoration: InputDecoration(
                        labelText: context.translate('composer_label'),
                        hintText: locProv.isSpanish ? 'ej. Claude Debussy' : 'e.g., Claude Debussy',
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
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.border, width: 1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedPdfName ?? context.translate('no_pdf_attached'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: _selectedPdfName != null ? Colors.white : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickPdf(setDialogState),
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
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    if (_titleController.text.trim().isNotEmpty) {
                      final targetBpm = int.tryParse(_bpmController.text) ?? 80;
                      final totalMeasures = int.tryParse(_measuresController.text) ?? 0;
                      
                      final piece = Piece(
                        id: 'piece_${DateTime.now().millisecondsSinceEpoch}',
                        title: _titleController.text.trim(),
                        composer: _composerController.text.trim().isEmpty 
                            ? 'Unknown' 
                            : _composerController.text.trim(),
                        targetBpm: targetBpm,
                        measuresTotal: totalMeasures,
                        measuresCompleted: 0,
                        pdfPath: _selectedPdfPath ?? _selectedPdfName,
                        notes: _notesController.text.trim(),
                      );
                      Provider.of<RepertoireProvider>(context, listen: false).savePiece(piece);
                      Navigator.of(context).pop();
                    }
                  },
                  child: Text(context.translate('add_btn')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPieceDetailsDialog(BuildContext context, Piece piece, RepertoireProvider provider) {
    int localCompleted = piece.measuresCompleted;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final progress = piece.measuresTotal > 0 ? (localCompleted / piece.measuresTotal).clamp(0.0, 1.0) : 0.0;
            return AlertDialog(
              title: Text(piece.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.translate('composer_format', [
                        piece.composer == 'Unknown' ? context.translate('unknown') : piece.composer
                      ]),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(context.translate('target_tempo_format', [piece.targetBpm.toString()]), style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 6),
                    if (piece.pdfPath != null)
                      Row(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              context.translate('score_sheet_format', [piece.pdfPath!.split(RegExp(r'[\\/]')).last]),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    const Divider(height: 24, color: AppTheme.border),
                    
                    // Progress Slider
                    Text(
                      context.translate('measures_progress_format', [localCompleted.toString(), piece.measuresTotal.toString()]),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.border,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                      ),
                    ),
                    if (piece.measuresTotal > 0) ...[
                      Slider(
                        min: 0,
                        max: piece.measuresTotal.toDouble(),
                        activeColor: AppTheme.secondary,
                        inactiveColor: AppTheme.border,
                        value: localCompleted.toDouble(),
                        onChanged: (double val) {
                          setDialogState(() {
                            localCompleted = val.round();
                          });
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    Text(context.translate('focus_notes_label'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      piece.notes.isEmpty ? context.translate('no_focus_notes') : piece.notes,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  onPressed: () {
                    provider.deletePiece(piece.id);
                    Navigator.of(context).pop();
                  },
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    provider.updatePieceProgress(piece.id, localCompleted);
                    Navigator.of(context).pop();
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
        title: Text(context.translate('repertoire_manager_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryAccent, size: 28),
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
                          Icon(Icons.library_music_rounded, size: 72, color: AppTheme.border.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text(
                            context.translate('repertoire_empty_title'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.translate('repertoire_empty_desc'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: repProv.pieces.length,
                    itemBuilder: (context, index) {
                      final piece = repProv.pieces[index];
                      return GestureDetector(
                        onTap: () => _showPieceDetailsDialog(context, piece, repProv),
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
                                            backgroundColor: AppTheme.border.withOpacity(0.5),
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child: Text(
                                          '${(piece.progressPercentage * 100).toStringAsFixed(0)}%',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      )
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                piece.composer == 'Unknown' ? context.translate('unknown') : piece.composer,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              
                              // Measures bar count
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    context.translate('meas_count_format', [piece.measuresCompleted.toString(), piece.measuresTotal.toString()]),
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${piece.targetBpm} BPM',
                                      style: const TextStyle(fontSize: 9, color: AppTheme.primaryAccent, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
