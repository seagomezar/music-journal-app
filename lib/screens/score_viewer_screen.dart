import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:provider/provider.dart';
import '../providers/practice_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';

class ScoreViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String pieceTitle;
  final int pieceBpm;

  const ScoreViewerScreen({
    super.key,
    required this.pdfPath,
    required this.pieceTitle,
    required this.pieceBpm,
  });

  @override
  State<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';

  // Bottom Navigation state
  int _activeNavIndex = 1; // 0: Metronome, 1: Navigation (Default), 2: Annotate

  // Annotations remain local to this viewer and are separated by PDF page.
  final Map<int, List<Offset?>> _annotationPointsByPage = {};

  List<Offset?> get _currentAnnotationPoints =>
      _annotationPointsByPage.putIfAbsent(_currentPage, () => []);

  @override
  void initState() {
    super.initState();
    // Pre-configure metronome BPM if provider has it default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final practiceProv = Provider.of<PracticeProvider>(
        context,
        listen: false,
      );
      if (practiceProv.metronomeBpm != widget.pieceBpm) {
        practiceProv.setMetronomeBpm(widget.pieceBpm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final practiceProv = Provider.of<PracticeProvider>(context);
    final hasPdf =
        !kIsWeb &&
        widget.pdfPath.isNotEmpty &&
        File(widget.pdfPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryColor(context)),
        title: Text(
          widget.pieceTitle,
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: AppTheme.primaryColor(context),
          ),
        ),
        actions: [
          if (_activeNavIndex == 2) // Annotate tab active
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              tooltip: context.translate('clear_annotations'),
              onPressed: () {
                setState(() {
                  _currentAnnotationPoints.clear();
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer
          if (hasPdf)
            Positioned.fill(
              child: PDFView(
                filePath: widget.pdfPath,
                enableSwipe:
                    _activeNavIndex == 1, // Enable swipe only in navigation tab
                swipeHorizontal: true,
                autoSpacing: true,
                pageFling: true,
                onRender: (pages) {
                  setState(() {
                    _totalPages = pages ?? 0;
                    _isReady = true;
                  });
                },
                onError: (error) {
                  setState(() {
                    _isReady = true;
                    _errorMessage = context.translate('pdf_load_error');
                  });
                },
                onPageError: (page, error) {
                  setState(() {
                    _isReady = true;
                    _errorMessage = context.translate('pdf_page_error', [
                      ((page ?? 0) + 1).toString(),
                    ]);
                  });
                },
                onPageChanged: (int? page, int? total) {
                  setState(() {
                    _currentPage = page ?? 0;
                  });
                },
              ),
            )
          else
            Center(
              child: Text(
                context.translate(
                  kIsWeb ? 'pdf_viewer_web_unavailable' : 'pdf_missing',
                ),
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),

          // Loading indicator
          if (hasPdf && !_isReady && _errorMessage.isEmpty)
            const Center(child: CircularProgressIndicator()),

          // Error Message display
          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // Drawing/Annotation Canvas Overlay
          if (_activeNavIndex == 2)
            Positioned.fill(
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _currentAnnotationPoints.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    _currentAnnotationPoints.add(null);
                  });
                },
                child: CustomPaint(
                  painter: AnnotationPainter(
                    _currentAnnotationPoints,
                    AppTheme.accentColor(context),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

          if (_activeNavIndex == 2)
            Positioned(
              top: 12,
              left: 24,
              right: 24,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(
                      context,
                    ).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      context.translate('annotations_temporary'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),

          // Page Indicator Overlay (Bottom-Right)
          if (_isReady && _totalPages > 0)
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.borderColor(context).withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  context.translate('page_of', [
                    (_currentPage + 1).toString(),
                    _totalPages.toString(),
                  ]),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Floating Metronome FAB
          Positioned(
            bottom: 24,
            left: 24,
            child: Semantics(
              button: true,
              label: context.translate('toggle_metronome'),
              child: GestureDetector(
                onTap: () {
                  practiceProv.toggleMetronome(widget.pieceBpm);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: practiceProv.metronomeOn
                        ? AppTheme.primaryColor(context)
                        : AppTheme.cardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: practiceProv.metronomeOn
                          ? AppTheme.accentColor(context)
                          : AppTheme.borderColor(context),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: practiceProv.metronomeOn
                                ? AppTheme.accentColor(context)
                                : AppTheme.textSecondaryColor(context),
                            size: 18,
                          ),
                          if (practiceProv.metronomeOn &&
                              practiceProv.metronomePulse)
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentColor(
                                  context,
                                ).withValues(alpha: 0.25),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.translate('tempo_label'),
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: practiceProv.metronomeOn
                                  ? AppTheme.accentColor(context)
                                  : AppTheme.textSecondaryColor(context),
                            ),
                          ),
                          Text(
                            '${practiceProv.metronomeBpm} BPM',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: practiceProv.metronomeOn
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.borderColor(context), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _activeNavIndex,
          onTap: (index) {
            if (index == 0) {
              // Open Metronome bottom sheet editor
              _showMetronomeSettings(context, practiceProv);
            } else {
              setState(() {
                _activeNavIndex = index;
              });
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.timer_outlined),
              label: context.translate('visual_metronome'),
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.menu_book_rounded,
                color: _activeNavIndex == 1
                    ? AppTheme.primaryColor(context)
                    : AppTheme.textSecondaryColor(context),
              ),
              label: context.translate('score_view'),
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.edit_note_rounded,
                color: _activeNavIndex == 2
                    ? AppTheme.primaryColor(context)
                    : AppTheme.textSecondaryColor(context),
              ),
              label: context.translate('annotate_score'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetronomeSettings(BuildContext context, PracticeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 20.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.translate('visual_metronome'),
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimaryColor(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline_rounded,
                          size: 36,
                          color: AppTheme.primaryColor(context),
                        ),
                        onPressed: () {
                          if (provider.metronomeBpm > 40) {
                            provider.setMetronomeBpm(provider.metronomeBpm - 1);
                            setSheetState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 24),
                      Text(
                        '${provider.metronomeBpm}',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.textPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          size: 36,
                          color: AppTheme.primaryColor(context),
                        ),
                        onPressed: () {
                          if (provider.metronomeBpm < 240) {
                            provider.setMetronomeBpm(provider.metronomeBpm + 1);
                            setSheetState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    min: 40,
                    max: 240,
                    value: provider.metronomeBpm.toDouble(),
                    activeColor: AppTheme.accentColor(context),
                    inactiveColor: AppTheme.borderColor(context),
                    onChanged: (val) {
                      provider.setMetronomeBpm(val.round());
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.metronomeOn
                          ? Colors.redAccent
                          : AppTheme.primaryColor(context),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      provider.toggleMetronome(provider.metronomeBpm);
                      setSheetState(() {});
                      setState(() {});
                    },
                    child: Text(
                      provider.metronomeOn
                          ? context.translate('stop_metronome')
                          : context.translate('start_metronome'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AnnotationPainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;

  AnnotationPainter(this.points, this.strokeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        paint.strokeWidth = 3.5;
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
