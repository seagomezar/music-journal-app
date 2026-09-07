import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/routine.dart';
import '../models/exercise.dart';
import '../models/piece.dart';
import '../providers/routine_provider.dart';
import '../providers/localization_provider.dart';
import '../providers/repertoire_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_layout.dart';

class _PendingExercisePdf {
  const _PendingExercisePdf({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

class RoutineConfigView extends StatefulWidget {
  const RoutineConfigView({super.key});

  @override
  State<RoutineConfigView> createState() => _RoutineConfigViewState();
}

class _RoutineConfigViewState extends State<RoutineConfigView> {
  final TextEditingController _routineTitleController = TextEditingController();
  final TextEditingController _routineDescController = TextEditingController();

  final TextEditingController _exNameController = TextEditingController();
  final TextEditingController _exBpmController = TextEditingController();
  String _exArticulation = 'Staccato';

  final List<String> _articulations = [
    'Staccato',
    'Legato',
    'Double Tonguing',
    'Triple Tonguing',
    'Flutter Tonguing',
    'Tenuto',
    'Accents',
  ];

  String _titleFromFileName(String fileName) {
    return fileName.replaceFirst(RegExp(r'\.pdf$', caseSensitive: false), '');
  }

  Future<_PendingExercisePdf?> _pickDevicePdf(BuildContext context) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('pdf_web_unavailable'))),
      );
      return null;
    }
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
      );
      if (result == null) return null;
      final selected = result.files.single;
      final path = selected.path;
      if (path == null || path.isEmpty) return null;
      return _PendingExercisePdf(path: path, fileName: selected.name);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('pdf_pick_error'))),
        );
      }
      return null;
    }
  }

  Future<Piece?> _pickRepertoirePdf(BuildContext context) async {
    final repertoire = context.read<RepertoireProvider>();
    final pieces = repertoire.pieces
        .where((piece) => piece.pdfPath?.isNotEmpty ?? false)
        .toList();
    if (pieces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.translate('no_repertoire_pdfs_available')),
        ),
      );
      return null;
    }
    return showModalBottomSheet<Piece>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    sheetContext.translate('choose_from_repertoire'),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: pieces.length,
                  itemBuilder: (context, index) {
                    final piece = pieces[index];
                    final matchingFolders = repertoire.folders.where(
                      (item) => item.id == piece.folderId,
                    );
                    final folder = matchingFolders.isEmpty
                        ? null
                        : matchingFolders.first;
                    return ListTile(
                      leading: const Icon(Icons.picture_as_pdf_rounded),
                      title: Text(piece.title),
                      subtitle: Text(
                        [
                          if (folder != null) folder.name,
                          piece.composer == 'Unknown'
                              ? sheetContext.translate('unknown')
                              : piece.composer,
                        ].join(' • '),
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(piece),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _routineTitleController.dispose();
    _routineDescController.dispose();
    _exNameController.dispose();
    _exBpmController.dispose();
    super.dispose();
  }

  void _showAddRoutineDialog(BuildContext context) {
    _routineTitleController.clear();
    _routineDescController.clear();
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: Text(context.translate('new_routine_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _routineTitleController,
                decoration: InputDecoration(
                  labelText: context.translate('routine_title_label'),
                  hintText: locProv.isSpanish
                      ? 'ej. Escalas Mañaneras'
                      : 'e.g., Morning Scales & Tone',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _routineDescController,
                decoration: InputDecoration(
                  labelText: context.translate('routine_desc_label'),
                  hintText: locProv.isSpanish
                      ? 'ej. Enfoque en la embocadura...'
                      : 'Focus on embouchure and breath control...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.translate('cancel'),
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor(context),
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () async {
                final title = _routineTitleController.text.trim();
                final description = _routineDescController.text.trim();
                if (title.isNotEmpty &&
                    title.length <= 100 &&
                    description.length <= 500) {
                  final routine = Routine(
                    id: 'routine_${const Uuid().v7()}',
                    title: title,
                    description: description,
                    exercises: [],
                  );
                  try {
                    await Provider.of<RoutineProvider>(
                      context,
                      listen: false,
                    ).saveRoutine(routine);
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.translate('routine_save_error'),
                          ),
                        ),
                      );
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        context.translate('invalid_routine_values'),
                      ),
                    ),
                  );
                }
              },
              child: Text(context.translate('create_btn')),
            ),
          ],
        );
      },
    );
  }

  void _showExerciseDialog(
    BuildContext context,
    Routine routine, {
    Exercise? exercise,
  }) {
    final isEditing = exercise != null;
    _exNameController.text = exercise?.name ?? '';
    _exBpmController.text = (exercise?.targetBpm ?? 80).toString();
    _exArticulation = exercise?.articulation ?? 'Staccato';
    final articulationOptions = List<String>.from(_articulations);
    if (!articulationOptions.contains(_exArticulation)) {
      articulationOptions.add(_exArticulation);
    }
    final locProv = Provider.of<LocalizationProvider>(context, listen: false);
    String? selectedPieceId = exercise?.musicSheetPieceId;
    _PendingExercisePdf? pendingPdf;
    var isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final repertoire = context.read<RepertoireProvider>();
            Piece? selectedPiece;
            for (final piece in repertoire.pieces) {
              if (piece.id == selectedPieceId) {
                selectedPiece = piece;
                break;
              }
            }
            final hasAttachment = pendingPdf != null || selectedPieceId != null;
            final selectedPieceHasPdf =
                selectedPiece?.pdfPath?.isNotEmpty ?? false;
            final attachmentTitle =
                pendingPdf?.fileName ??
                (selectedPieceHasPdf ? selectedPiece!.title : null) ??
                context.translate('score_unavailable');
            return AlertDialog(
              scrollable: true,
              title: Text(
                context.translate(
                  isEditing ? 'edit_exercise_title' : 'add_exercise_to',
                  [routine.title],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _exNameController,
                    enabled: !isSaving,
                    decoration: InputDecoration(
                      labelText: context.translate('exercise_name_label'),
                      hintText: locProv.isSpanish
                          ? 'ej. Doble golpe en Sol Mayor'
                          : 'e.g., T-K Staccato in G Major',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _exBpmController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.translate('target_bpm_tempo'),
                      suffixText: 'BPM',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _exArticulation,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.translate('articulation_label'),
                    ),
                    items: articulationOptions.map((String art) {
                      return DropdownMenuItem<String>(
                        value: art,
                        child: Text(art),
                      );
                    }).toList(),
                    onChanged: isSaving
                        ? null
                        : (val) {
                            if (val != null) {
                              setDialogState(() {
                                _exArticulation = val;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderColor(context)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.translate('music_sheet'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              hasAttachment
                                  ? Icons.picture_as_pdf_rounded
                                  : Icons.insert_drive_file_outlined,
                              color: hasAttachment
                                  ? Colors.redAccent
                                  : AppTheme.textSecondaryColor(context),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasAttachment
                                    ? attachmentTitle
                                    : context.translate(
                                        'no_music_sheet_attached',
                                      ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasAttachment)
                              IconButton(
                                tooltip: context.translate(
                                  'remove_music_sheet',
                                ),
                                onPressed: isSaving
                                    ? null
                                    : () => setDialogState(() {
                                        selectedPieceId = null;
                                        pendingPdf = null;
                                      }),
                                icon: const Icon(Icons.close_rounded),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final piece = await _pickRepertoirePdf(
                                        context,
                                      );
                                      if (piece != null && context.mounted) {
                                        setDialogState(() {
                                          selectedPieceId = piece.id;
                                          pendingPdf = null;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.library_music_rounded),
                              label: Text(
                                context.translate('choose_from_repertoire'),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      final picked = await _pickDevicePdf(
                                        context,
                                      );
                                      if (picked != null && context.mounted) {
                                        setDialogState(() {
                                          pendingPdf = picked;
                                          selectedPieceId = null;
                                        });
                                      }
                                    },
                              icon: const Icon(Icons.upload_file_rounded),
                              label: Text(
                                context.translate('import_pdf_from_device'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
                          if (isSaving) return;
                          final bpm = int.tryParse(_exBpmController.text);
                          final name = _exNameController.text.trim();
                          final repertoireProvider = context
                              .read<RepertoireProvider>();
                          final routineProvider = context
                              .read<RoutineProvider>();
                          if (name.isNotEmpty &&
                              name.length <= 100 &&
                              bpm != null &&
                              bpm >= 30 &&
                              bpm <= 252) {
                            setDialogState(() => isSaving = true);
                            String? importedPieceId;
                            try {
                              var attachmentId = selectedPieceId;
                              if (pendingPdf != null) {
                                final newPiece = Piece(
                                  id: 'piece_${const Uuid().v7()}',
                                  title: _titleFromFileName(
                                    pendingPdf!.fileName,
                                  ),
                                  composer: 'Unknown',
                                  pdfPath: pendingPdf!.path,
                                  targetBpm: bpm,
                                );
                                await repertoireProvider.savePiece(
                                  newPiece,
                                  pdfOriginalName: pendingPdf!.fileName,
                                );
                                importedPieceId = newPiece.id;
                                attachmentId = newPiece.id;
                              }
                              final updatedExercise = exercise != null
                                  ? exercise.copyWith(
                                      name: name,
                                      targetBpm: bpm,
                                      articulation: _exArticulation,
                                      musicSheetPieceId: attachmentId,
                                    )
                                  : Exercise(
                                      id: 'ex_${const Uuid().v7()}',
                                      name: name,
                                      targetBpm: bpm,
                                      articulation: _exArticulation,
                                      musicSheetPieceId: attachmentId,
                                    );
                              final updatedExercises = List<Exercise>.from(
                                routine.exercises,
                              );
                              if (exercise != null) {
                                final exerciseIndex = updatedExercises
                                    .indexWhere(
                                      (candidate) =>
                                          candidate.id == exercise.id,
                                    );
                                if (exerciseIndex == -1) {
                                  throw StateError(
                                    'Exercise no longer exists.',
                                  );
                                }
                                updatedExercises[exerciseIndex] =
                                    updatedExercise;
                              } else {
                                updatedExercises.add(updatedExercise);
                              }
                              await routineProvider.saveRoutine(
                                routine.copyWith(exercises: updatedExercises),
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            } catch (error) {
                              if (importedPieceId != null) {
                                try {
                                  await repertoireProvider.deletePiece(
                                    importedPieceId,
                                  );
                                } catch (_) {}
                              }
                              if (context.mounted) {
                                setDialogState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.translate('routine_save_error'),
                                    ),
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  context.translate('invalid_exercise_values'),
                                ),
                              ),
                            );
                          }
                        },
                  child: Text(
                    context.translate(isEditing ? 'save' : 'add_btn'),
                  ),
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
    final routineProv = Provider.of<RoutineProvider>(context);
    final repertoireProv = Provider.of<RepertoireProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.translate('routines_tab_title'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.add_circle_outline_rounded,
              color: AppTheme.accentColor(context),
              size: 28,
            ),
            tooltip: context.translate('add_routine'),
            onPressed: () => _showAddRoutineDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AdaptiveContent(
          child: routineProv.isLoading
              ? const Center(child: CircularProgressIndicator())
              : routineProv.routines.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.playlist_add_circle_rounded,
                          size: 72,
                          color: AppTheme.borderColor(
                            context,
                          ).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.translate('no_routines_configured_empty'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.translate('click_add_routine'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: routineProv.routines.length,
                  itemBuilder: (context, index) {
                    final routine = routineProv.routines[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: AppTheme.glassCard(
                        padding: EdgeInsets.zero,
                        child: Material(
                          type: MaterialType.transparency,
                          child: ExpansionTile(
                            internalAddSemanticForOnTap: true,
                            shape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            collapsedShape: const RoundedRectangleBorder(
                              side: BorderSide.none,
                            ),
                            tilePadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor(
                                  context,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.my_library_music_rounded,
                                color: AppTheme.accentColor(context),
                              ),
                            ),
                            title: Text(
                              routine.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              routine.description.isEmpty
                                  ? context.translate(
                                      'technical_exercises_default',
                                    )
                                  : routine.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor(context),
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              tooltip: context.translate('delete_btn'),
                              onPressed: () {
                                _showDeleteRoutineConfirm(context, routine);
                              },
                            ),
                            children: [
                              Divider(
                                height: 1,
                                color: AppTheme.borderColor(context),
                              ),
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: Colors.black12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            context.translate(
                                              'technical_checklist',
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.accentColor(context),
                                            padding: EdgeInsets.zero,
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: Text(
                                            context.translate('add_exercise'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                          onPressed: () => _showExerciseDialog(
                                            context,
                                            routine,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (routine.exercises.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        child: Center(
                                          child: Text(
                                            context.translate(
                                              'no_exercises_added',
                                            ),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppTheme.textSecondaryColor(
                                                    context,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else ...[
                                      if (routine.exercises.length > 1)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            context.translate(
                                              'reorder_exercises_hint',
                                            ),
                                            style: TextStyle(
                                              color:
                                                  AppTheme.textSecondaryColor(
                                                    context,
                                                  ),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ReorderableListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        buildDefaultDragHandles: false,
                                        itemCount: routine.exercises.length,
                                        onReorderItem:
                                            (oldIndex, newIndex) async {
                                              await _reorderExercises(
                                                context,
                                                routine,
                                                oldIndex,
                                                newIndex,
                                              );
                                            },
                                        itemBuilder: (context, idx) {
                                          final exercise =
                                              routine.exercises[idx];
                                          final matchingPieces = repertoireProv
                                              .pieces
                                              .where(
                                                (piece) =>
                                                    piece.id ==
                                                    exercise.musicSheetPieceId,
                                              );
                                          final attachedPiece =
                                              matchingPieces.isEmpty
                                              ? null
                                              : matchingPieces.first;
                                          return Container(
                                            key: ValueKey(
                                              'exercise_${routine.id}_${exercise.id}',
                                            ),
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppTheme.surfaceColor(
                                                context,
                                              ).withValues(alpha: 0.4),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppTheme.borderColor(
                                                  context,
                                                ).withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _getArticulationIcon(
                                                    exercise.articulation,
                                                  ),
                                                  color: AppTheme.accentColor(
                                                    context,
                                                  ).withValues(alpha: 0.7),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        exercise.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        context.translate(
                                                          'exercise_detail_format',
                                                          [
                                                            exercise
                                                                .articulation,
                                                            exercise.targetBpm
                                                                .toString(),
                                                          ],
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: AppTheme
                                                              .textSecondary,
                                                        ),
                                                      ),
                                                      if (exercise
                                                              .musicSheetPieceId !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 3,
                                                        ),
                                                        Row(
                                                          children: [
                                                            const Icon(
                                                              Icons
                                                                  .picture_as_pdf_rounded,
                                                              size: 13,
                                                              color: Colors
                                                                  .redAccent,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                attachedPiece
                                                                        ?.title ??
                                                                    context.translate(
                                                                      'score_unavailable',
                                                                    ),
                                                                maxLines: 1,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  key: ValueKey(
                                                    'edit_exercise_${exercise.id}',
                                                  ),
                                                  constraints:
                                                      const BoxConstraints.tightFor(
                                                        width: 44,
                                                        height: 44,
                                                      ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  icon: Icon(
                                                    Icons.edit_outlined,
                                                    color: AppTheme.accentColor(
                                                      context,
                                                    ),
                                                    size: 18,
                                                  ),
                                                  tooltip: context.translate(
                                                    'edit_exercise',
                                                  ),
                                                  onPressed: () =>
                                                      _showExerciseDialog(
                                                        context,
                                                        routine,
                                                        exercise: exercise,
                                                      ),
                                                ),
                                                IconButton(
                                                  constraints:
                                                      const BoxConstraints.tightFor(
                                                        width: 44,
                                                        height: 44,
                                                      ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  visualDensity:
                                                      VisualDensity.compact,
                                                  icon: const Icon(
                                                    Icons
                                                        .remove_circle_outline_rounded,
                                                    color: Colors.redAccent,
                                                    size: 16,
                                                  ),
                                                  tooltip: context.translate(
                                                    'delete_btn',
                                                  ),
                                                  onPressed: () async {
                                                    final updated =
                                                        List<Exercise>.from(
                                                          routine.exercises,
                                                        )..removeAt(idx);
                                                    try {
                                                      await routineProv
                                                          .saveRoutine(
                                                            routine.copyWith(
                                                              exercises:
                                                                  updated,
                                                            ),
                                                          );
                                                    } catch (error) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              context.translate(
                                                                'routine_save_error',
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                                ReorderableDragStartListener(
                                                  key: ValueKey(
                                                    'exercise_drag_${exercise.id}',
                                                  ),
                                                  index: idx,
                                                  child: Tooltip(
                                                    message: context.translate(
                                                      'reorder_exercise',
                                                    ),
                                                    child: Semantics(
                                                      button: true,
                                                      label: context.translate(
                                                        'reorder_exercise',
                                                      ),
                                                      child: const SizedBox(
                                                        width: 44,
                                                        height: 44,
                                                        child: Icon(
                                                          Icons
                                                              .drag_handle_rounded,
                                                          color: AppTheme
                                                              .textSecondary,
                                                          size: 22,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _reorderExercises(
    BuildContext context,
    Routine routine,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex == oldIndex) return;

    final updatedExercises = List<Exercise>.from(routine.exercises);
    final movedExercise = updatedExercises.removeAt(oldIndex);
    updatedExercises.insert(newIndex, movedExercise);

    try {
      await Provider.of<RoutineProvider>(
        context,
        listen: false,
      ).saveRoutine(routine.copyWith(exercises: updatedExercises));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('routine_save_error'))),
        );
      }
    }
  }

  void _showDeleteRoutineConfirm(BuildContext context, Routine routine) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('delete_routine_title')),
          content: Text(
            context.translate('delete_routine_confirm', [routine.title]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.translate('cancel'),
                style: TextStyle(color: AppTheme.textSecondaryColor(context)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  await Provider.of<RoutineProvider>(
                    context,
                    listen: false,
                  ).deleteRoutine(routine.id);
                  if (context.mounted) Navigator.of(context).pop();
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.translate('routine_delete_error'),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(context.translate('delete_btn')),
            ),
          ],
        );
      },
    );
  }

  IconData _getArticulationIcon(String art) {
    switch (art.toLowerCase()) {
      case 'legato':
        return Icons.gesture_rounded;
      case 'staccato':
        return Icons.blur_on_rounded;
      case 'double tonguing':
        return Icons.repeat_rounded;
      case 'triple tonguing':
        return Icons.repeat_on_rounded;
      case 'flutter tonguing':
        return Icons.waves_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }
}
