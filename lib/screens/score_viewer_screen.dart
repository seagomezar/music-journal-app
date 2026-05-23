import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:google_fonts/google_fonts.dart';
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
  PDFViewController? _pdfViewController;

  // Bottom Navigation state
  int _activeNavIndex = 1; // 0: Metronome, 1: Navigation (Default), 2: Annotate

  // Annotation points list
  final List<Offset?> _annotationPoints = [];

  @override
  void initState() {
    super.initState();
    // Pre-configure metronome BPM if provider has it default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final practiceProv = Provider.of<PracticeProvider>(context, listen: false);
      if (practiceProv.metronomeBpm != widget.pieceBpm) {
        practiceProv.setMetronomeBpm(widget.pieceBpm);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final practiceProv = Provider.of<PracticeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.primary),
        title: Text(
          widget.pieceTitle,
          style: GoogleFonts.ebGaramond(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: AppTheme.primary,
          ),
        ),
        actions: [
          if (_activeNavIndex == 2) // Annotate tab active
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: 'Clear Annotations',
              onPressed: () {
                setState(() {
                  _annotationPoints.clear();
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          // PDF Viewer
          if (widget.pdfPath.isNotEmpty && File(widget.pdfPath).existsSync())
            Positioned.fill(
              child: PDFView(
                filePath: widget.pdfPath,
                enableSwipe: _activeNavIndex == 1, // Enable swipe only in navigation tab
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
                    _errorMessage = error.toString();
                  });
                },
                onPageError: (page, error) {
                  setState(() {
                    _errorMessage = 'Page $page: ${error.toString()}';
                  });
                },
                onViewCreated: (PDFViewController controller) {
                  _pdfViewController = controller;
                },
                onPageChanged: (int? page, int? total) {
                  setState(() {
                    _currentPage = page ?? 0;
                  });
                },
              ),
            )
          else
            const Center(
              child: Text(
                'PDF file not found or path is empty.',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),

          // Loading indicator
          if (!_isReady && _errorMessage.isEmpty)
            const Center(
              child: CircularProgressIndicator(),
            ),

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
                    RenderBox renderBox = context.findRenderObject() as RenderBox;
                    _annotationPoints.add(renderBox.globalToLocal(details.globalPosition));
                  });
                },
                onPanEnd: (details) {
                  setState(() {
                    _annotationPoints.add(null); // break stroke
                  });
                },
                child: CustomPaint(
                  painter: AnnotationPainter(_annotationPoints, AppTheme.primaryAccent),
                  size: Size.infinite,
                ),
              ),
            ),

          // Page Indicator Overlay (Bottom-Right)
          if (_isReady && _totalPages > 0)
            Positioned(
              bottom: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Text(
                  '${context.translate('page_label') ?? 'Page'} ${_currentPage + 1} of $_totalPages',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

          // Floating Metronome FAB
          Positioned(
            bottom: 24,
            left: 24,
            child: GestureDetector(
              onTap: () {
                practiceProv.toggleMetronome(widget.pieceBpm);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: practiceProv.metronomeOn 
                      ? AppTheme.primary 
                      : AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: practiceProv.metronomeOn 
                        ? AppTheme.primaryAccent 
                        : AppTheme.border,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
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
                              ? AppTheme.primaryAccent 
                              : AppTheme.textSecondary,
                          size: 18,
                        ),
                        if (practiceProv.metronomeOn && practiceProv.metronomePulse)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryAccent.withOpacity(0.25),
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
                          'TEMPO',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: practiceProv.metronomeOn 
                                ? AppTheme.primaryAccent 
                                : AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          '${practiceProv.metronomeBpm} BPM',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: practiceProv.metronomeOn 
                                ? Colors.white 
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 1),
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
              label: context.translate('visual_metronome') ?? 'Metronome',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.menu_book_rounded,
                color: _activeNavIndex == 1 ? AppTheme.primary : AppTheme.textSecondary,
              ),
              label: context.translate('score_view') ?? 'Navigation',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.edit_note_rounded,
                color: _activeNavIndex == 2 ? AppTheme.primary : AppTheme.textSecondary,
              ),
              label: context.translate('annotate_score') ?? 'Annotate',
            ),
          ],
        ),
      ),
    );
  }

  void _showMetronomeSettings(BuildContext context, PracticeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.translate('visual_metronome') ?? 'Visual Metronome',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 36, color: AppTheme.primary),
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
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 36, color: AppTheme.primary),
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
                    activeColor: AppTheme.primaryAccent,
                    inactiveColor: AppTheme.border,
                    onChanged: (val) {
                      provider.setMetronomeBpm(val.round());
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.metronomeOn ? Colors.redAccent : AppTheme.primary,
                      foregroundColor: Colors.white,
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
                          ? (context.translate('stop_metronome') ?? 'Stop')
                          : (context.translate('start_metronome') ?? 'Start'),
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
