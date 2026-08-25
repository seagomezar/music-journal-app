import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../models/pdf_annotation.dart';
import '../models/score_view_preferences.dart';
import '../providers/localization_provider.dart';
import '../providers/practice_provider.dart';
import '../services/annotated_pdf_export_service.dart';
import '../services/database_service.dart';
import '../services/pdf_annotation_service.dart';
import '../services/performance_display_service.dart';
import '../services/score_view_preferences_service.dart';
import '../services/screen_awake_service.dart';
import '../theme/app_theme.dart';

@visibleForTesting
int scoreSpreadStart(int page, {required bool firstPageOnRight}) {
  if (firstPageOnRight && page == 1) return 1;
  if (firstPageOnRight) return page.isEven ? page : page - 1;
  return page.isOdd ? page : page - 1;
}

@visibleForTesting
int nextScoreSpread(int page, int pageCount, {required bool firstPageOnRight}) {
  final start = scoreSpreadStart(page, firstPageOnRight: firstPageOnRight);
  final next = firstPageOnRight && start == 1 ? 2 : start + 2;
  return next <= pageCount ? next : start;
}

@visibleForTesting
int previousScoreSpread(int page, {required bool firstPageOnRight}) {
  final start = scoreSpreadStart(page, firstPageOnRight: firstPageOnRight);
  if (firstPageOnRight && start == 2) return 1;
  return math.max(1, start - 2);
}

@visibleForTesting
String scorePageLabel({
  required int page,
  required int pageCount,
  required ScoreLayoutMode layoutMode,
  required bool firstPageOnRight,
}) {
  if (layoutMode != ScoreLayoutMode.twoPage) return '$page/$pageCount';
  final start = scoreSpreadStart(page, firstPageOnRight: firstPageOnRight);
  final end = firstPageOnRight && start == 1
      ? 1
      : math.min(pageCount, start + 1);
  return start == end ? '$start/$pageCount' : '$start–$end/$pageCount';
}

@visibleForTesting
double scoreAutoScrollRate({
  required AutoScrollPaceMode mode,
  required double visibleHeight,
  required double documentHeight,
  required double viewportHeightsPerMinute,
  required int durationSeconds,
}) {
  if (mode == AutoScrollPaceMode.speed) {
    return visibleHeight * viewportHeightsPerMinute / 60;
  }
  return math.max(1, (documentHeight - visibleHeight) / durationSeconds);
}

class ScoreViewerScreen extends StatefulWidget {
  final String pieceId;
  final String pdfPath;
  final String pieceTitle;
  final int pieceBpm;
  final PdfAnnotationRepository? annotationRepository;
  final AnnotatedPdfExporter? annotatedPdfExporter;
  final ScoreViewPreferencesRepository? preferencesRepository;
  final PerformanceDisplayController? performanceDisplayController;
  final ScreenAwakeCoordinator? screenAwakeCoordinator;

  const ScoreViewerScreen({
    super.key,
    required this.pieceId,
    required this.pdfPath,
    required this.pieceTitle,
    required this.pieceBpm,
    this.annotationRepository,
    this.annotatedPdfExporter,
    this.preferencesRepository,
    this.performanceDisplayController,
    this.screenAwakeCoordinator,
  });

  @override
  State<ScoreViewerScreen> createState() => _ScoreViewerScreenState();
}

class _ScoreViewerScreenState extends State<ScoreViewerScreen>
    with WidgetsBindingObserver {
  late final PdfAnnotationRepository _annotationRepository;
  late final AnnotatedPdfExporter _annotatedPdfExporter;
  late final ScoreViewPreferencesRepository _preferencesRepository;
  late final PerformanceDisplayController _displayController;
  late final ScreenAwakeCoordinator _screenAwakeCoordinator;
  final PdfViewerController _pdfController = PdfViewerController();
  final Map<int, List<PdfInkStroke>> _strokesByPage = {};

  late ScoreViewPreferences _preferences;
  Future<void> _annotationSaveQueue = Future.value();
  Future<void> _preferenceSaveQueue = Future.value();
  Timer? _preferenceDebounce;
  Timer? _autoScrollTimer;
  DateTime? _lastAutoScrollTick;
  DateTime? _lastPedalCommand;

  int _totalPages = 0;
  int _currentPage = 1;
  int _annotationPage = 1;
  int _activeNavIndex = 1;
  bool _isReady = false;
  bool _annotationsLoaded = false;
  bool _preferencesLoaded = false;
  bool _isExporting = false;
  bool _saveErrorShown = false;
  bool _isPerformanceMode = false;
  bool _performanceControlsVisible = false;
  bool _touchLocked = false;
  bool _showingHalfBoundary = false;
  bool _autoScrollRunning = false;
  double _brightness = 1;

  bool get _hasAnnotations =>
      _strokesByPage.values.any((strokes) => strokes.isNotEmpty);

  bool get _hasPdf =>
      !kIsWeb && widget.pdfPath.isNotEmpty && File(widget.pdfPath).existsSync();

  ScoreLayoutMode get _effectiveLayoutMode {
    if (_preferences.layoutMode == ScoreLayoutMode.twoPage &&
        MediaQuery.sizeOf(context).width < MediaQuery.sizeOf(context).height) {
      return ScoreLayoutMode.singlePage;
    }
    return _preferences.layoutMode;
  }

  bool get _viewerCanPan =>
      !_isPerformanceMode &&
      _activeNavIndex == 1 &&
      (_effectiveLayoutMode == ScoreLayoutMode.continuous ||
          _preferences.fitMode == ScoreFitMode.fitWidth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _annotationRepository =
        widget.annotationRepository ?? PdfAnnotationService();
    _annotatedPdfExporter =
        widget.annotatedPdfExporter ?? OpenSourceAnnotatedPdfExporter();
    _preferencesRepository =
        widget.preferencesRepository ?? ScoreViewPreferencesService();
    _displayController =
        widget.performanceDisplayController ??
        SystemPerformanceDisplayController();
    _screenAwakeCoordinator =
        widget.screenAwakeCoordinator ?? ScreenAwakeCoordinator.instance;
    _preferences = ScoreViewPreferences.defaults(
      pieceId: widget.pieceId,
      sourcePath: widget.pdfPath,
    );
    _brightness = DatabaseService().getPerformanceBrightness();
    unawaited(_loadInitialState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final practice = context.read<PracticeProvider>();
      if (practice.metronomeBpm != widget.pieceBpm) {
        practice.setMetronomeBpm(widget.pieceBpm);
      }
    });
  }

  Future<void> _loadInitialState() async {
    await Future.wait([_loadAnnotations(), _loadPreferences()]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _preferencesLoaded) {
      unawaited(_applyDisplayState());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _preferenceDebounce?.cancel();
    if (_preferencesLoaded) {
      final finalPreferences = _preferences.copyWith(lastPage: _currentPage);
      unawaited(
        _preferenceSaveQueue
            .then((_) => _preferencesRepository.save(finalPreferences))
            .catchError((Object error, StackTrace stackTrace) {
              debugPrint('Final score view preference save failed: $error');
            }),
      );
    }
    _stopAutoScroll(updateState: false);
    unawaited(
      _screenAwakeCoordinator.setPerformanceEnabled(false).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Unable to release performance wakelock: $error');
      }),
    );
    unawaited(
      _displayController.restore().catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('Unable to restore score display: $error');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final practice = context.read<PracticeProvider>();
    return PopScope(
      canPop: !_isPerformanceMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isPerformanceMode) unawaited(_leavePerformanceMode());
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _isPerformanceMode ? null : _buildAppBar(),
        body: _buildBody(practice),
        bottomNavigationBar: _isPerformanceMode
            ? null
            : _buildBottomNavigation(practice),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          tooltip: context.translate('score_display_options'),
          onPressed: _isReady ? _showDisplayOptions : null,
        ),
        IconButton(
          icon: const Icon(Icons.play_circle_fill_rounded),
          tooltip: context.translate('performance_mode'),
          onPressed: _isReady ? _enterPerformanceMode : null,
        ),
        if (_isExporting)
          const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: context.translate('export_annotated_pdf'),
            onPressed: _hasPdf && _annotationsLoaded && _hasAnnotations
                ? _exportAnnotatedPdf
                : null,
          ),
        if (_activeNavIndex == 2)
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
            ),
            tooltip: context.translate('clear_annotations'),
            onPressed: (_strokesByPage[_annotationPage]?.isNotEmpty ?? false)
                ? _confirmClearCurrentPage
                : null,
          ),
      ],
    );
  }

  Widget _buildBody(PracticeProvider practice) {
    if (!_hasPdf) {
      return Center(
        child: Text(
          context.translate(
            kIsWeb ? 'pdf_viewer_web_unavailable' : 'pdf_missing',
          ),
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (!_preferencesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(child: _buildFilteredViewer()),
        if (!_isReady) const Center(child: CircularProgressIndicator()),
        if (!_isPerformanceMode && _activeNavIndex == 1 && _isReady)
          _buildNormalPageTurnLayer(),
        if (!_isPerformanceMode && _activeNavIndex == 2)
          _buildAnnotationNotice(),
        if (!_isPerformanceMode && _isReady) _buildPageIndicator(),
        if (!_isPerformanceMode)
          ListenableBuilder(
            listenable: practice,
            builder: (context, child) => _buildMetronomeBadge(practice),
          ),
        if (_isPerformanceMode) _buildPerformanceTouchLayer(),
        if (_isPerformanceMode && _performanceControlsVisible)
          ListenableBuilder(
            listenable: practice,
            builder: (context, child) => _buildPerformanceControls(practice),
          ),
        if (_preferences.layoutMode == ScoreLayoutMode.halfPage &&
            _showingHalfBoundary &&
            (_performanceControlsVisible || !_isPerformanceMode))
          _buildHalfPageDivider(),
      ],
    );
  }

  Widget _buildFilteredViewer() {
    final viewer = PdfViewer.file(
      widget.pdfPath,
      controller: _pdfController,
      initialPageNumber: _preferences.lastPage,
      params: PdfViewerParams(
        backgroundColor: AppTheme.backgroundColor(context),
        panEnabled: _viewerCanPan,
        scaleEnabled: !_isPerformanceMode && _activeNavIndex == 1,
        layoutPages: _effectiveLayoutMode == ScoreLayoutMode.twoPage
            ? _buildFacingPageLayout
            : null,
        onViewerReady: (document, controller) {
          if (!mounted) return;
          setState(() {
            _totalPages = document.pages.length;
            _currentPage = _preferences.lastPage.clamp(1, _totalPages);
            _annotationPage = _currentPage;
            _isReady = true;
          });
          controller.requestFocus();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_applyCurrentView());
          });
        },
        onPageChanged: (pageNumber) {
          if (!mounted || pageNumber == null || _showingHalfBoundary) return;
          final bounded = pageNumber.clamp(1, math.max(1, _totalPages)).toInt();
          if (_currentPage != bounded) {
            setState(() {
              _currentPage = bounded;
              _annotationPage = bounded;
            });
            _schedulePreferenceSave();
          }
        },
        onInteractionStart: (_) {
          if (_autoScrollRunning) _stopAutoScroll();
        },
        onViewSizeChanged: (viewSize, oldViewSize, controller) {
          if (oldViewSize == null || viewSize == oldViewSize) return;
          Future.delayed(const Duration(milliseconds: 120), () {
            if (mounted && _isReady) unawaited(_applyCurrentView());
          });
        },
        onKey: _handleViewerKey,
        keyHandlerParams: const PdfViewerKeyHandlerParams(autofocus: true),
        pageOverlaysBuilder: (overlayContext, pageRect, page) => [
          _buildPageAnnotationOverlay(overlayContext, page),
        ],
        errorBannerBuilder: (errorContext, error, stackTrace, documentRef) =>
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  errorContext.translate('pdf_load_error'),
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      ),
    );

    return switch (_preferences.colorMode) {
      ScoreColorMode.normal => viewer,
      ScoreColorMode.sepia => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: viewer,
      ),
      ScoreColorMode.inverted => ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1,
          0,
          0,
          0,
          255,
          0,
          -1,
          0,
          0,
          255,
          0,
          0,
          -1,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: viewer,
      ),
    };
  }

  PdfPageLayout _buildFacingPageLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
  ) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const [], documentSize: Size.zero);
    }
    final columnWidth = pages.map((page) => page.width).reduce(math.max);
    final rowHeight = pages.map((page) => page.height).reduce(math.max);
    final layouts = List<Rect>.filled(pages.length, Rect.zero);
    var maxRow = 0;
    for (var index = 0; index < pages.length; index++) {
      final pageNumber = index + 1;
      final row = _preferences.firstPageOnRight
          ? (pageNumber == 1 ? 0 : pageNumber ~/ 2)
          : index ~/ 2;
      final column = _preferences.firstPageOnRight
          ? (pageNumber == 1 ? 1 : (pageNumber.isEven ? 0 : 1))
          : index % 2;
      maxRow = math.max(maxRow, row);
      final page = pages[index];
      layouts[index] = Rect.fromLTWH(
        params.margin + column * (columnWidth + params.margin),
        params.margin +
            row * (rowHeight + params.margin) +
            (rowHeight - page.height) / 2,
        page.width,
        page.height,
      );
    }
    return PdfPageLayout(
      pageLayouts: layouts,
      documentSize: Size(
        columnWidth * 2 + params.margin * 3,
        (maxRow + 1) * rowHeight + (maxRow + 2) * params.margin,
      ),
    );
  }

  bool? _handleViewerKey(
    PdfViewerKeyHandlerParams params,
    LogicalKeyboardKey key,
    bool isRealKeyPress,
  ) {
    if (!isRealKeyPress) return true;
    final now = DateTime.now();
    if (_lastPedalCommand != null &&
        now.difference(_lastPedalCommand!) <
            const Duration(milliseconds: 250)) {
      return true;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final nextKeys = {
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.pageDown,
      LogicalKeyboardKey.enter,
    };
    final previousKeys = {
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.pageUp,
    };
    if ((key == LogicalKeyboardKey.space && !shift) || nextKeys.contains(key)) {
      _lastPedalCommand = now;
      unawaited(_navigateForward());
      return true;
    }
    if ((key == LogicalKeyboardKey.space && shift) ||
        previousKeys.contains(key)) {
      _lastPedalCommand = now;
      unawaited(_navigateBackward());
      return true;
    }
    if (key == LogicalKeyboardKey.escape && _isPerformanceMode) {
      unawaited(_leavePerformanceMode());
      return true;
    }
    return false;
  }

  Future<void> _navigateForward() async {
    if (!_isReady) return;
    if (_autoScrollRunning) _stopAutoScroll();
    switch (_effectiveLayoutMode) {
      case ScoreLayoutMode.halfPage:
        if (_showingHalfBoundary) {
          await _showFullPage((_currentPage + 1).clamp(1, _totalPages));
        } else if (_currentPage < _totalPages) {
          await _showHalfBoundary(_currentPage);
        }
      case ScoreLayoutMode.twoPage:
        final next = nextScoreSpread(
          _currentPage,
          _totalPages,
          firstPageOnRight: _preferences.firstPageOnRight,
        );
        if (next != _currentPage) await _showSpread(next);
      case ScoreLayoutMode.singlePage:
        if (_preferences.fitMode == ScoreFitMode.fitWidth &&
            _advanceWithinCurrentPage(forward: true)) {
          return;
        }
        if (_currentPage < _totalPages) await _showFullPage(_currentPage + 1);
      case ScoreLayoutMode.continuous:
        if (_currentPage < _totalPages) await _showFullPage(_currentPage + 1);
    }
  }

  Future<void> _navigateBackward() async {
    if (!_isReady) return;
    if (_autoScrollRunning) _stopAutoScroll();
    switch (_effectiveLayoutMode) {
      case ScoreLayoutMode.halfPage:
        if (_showingHalfBoundary) {
          await _showFullPage(_currentPage);
        } else if (_currentPage > 1) {
          await _showHalfBoundary(_currentPage - 1);
        }
      case ScoreLayoutMode.twoPage:
        final previous = previousScoreSpread(
          _currentPage,
          firstPageOnRight: _preferences.firstPageOnRight,
        );
        if (previous != _currentPage) await _showSpread(previous);
      case ScoreLayoutMode.singlePage:
        if (_preferences.fitMode == ScoreFitMode.fitWidth &&
            _advanceWithinCurrentPage(forward: false)) {
          return;
        }
        if (_currentPage > 1) await _showFullPage(_currentPage - 1);
      case ScoreLayoutMode.continuous:
        if (_currentPage > 1) await _showFullPage(_currentPage - 1);
    }
  }

  bool _advanceWithinCurrentPage({required bool forward}) {
    final pageRect = _pdfController.layout.pageLayouts[_currentPage - 1];
    final visible = _pdfController.visibleRect;
    final overlap = visible.height * 0.1;
    if (forward && visible.bottom < pageRect.bottom - overlap) {
      final centerY = math.min(
        pageRect.bottom - visible.height / 2,
        visible.center.dy + visible.height - overlap,
      );
      _pdfController.value = _pdfController.calcMatrixFor(
        Offset(pageRect.center.dx, centerY),
      );
      return true;
    }
    if (!forward && visible.top > pageRect.top + overlap) {
      final centerY = math.max(
        pageRect.top + visible.height / 2,
        visible.center.dy - visible.height + overlap,
      );
      _pdfController.value = _pdfController.calcMatrixFor(
        Offset(pageRect.center.dx, centerY),
      );
      return true;
    }
    return false;
  }

  Future<void> _showFullPage(int page) async {
    final bounded = page.clamp(1, _totalPages);
    _showingHalfBoundary = false;
    if (_effectiveLayoutMode == ScoreLayoutMode.twoPage) {
      await _showSpread(bounded);
      return;
    }
    final matrix =
        _preferences.fitMode == ScoreFitMode.fitWidth ||
            _effectiveLayoutMode == ScoreLayoutMode.continuous
        ? _pdfController.calcMatrixFitWidthForPage(pageNumber: bounded)
        : _pdfController.calcMatrixForFit(pageNumber: bounded);
    if (matrix != null) _pdfController.value = matrix;
    _pdfController.setCurrentPageNumber(bounded);
    if (mounted) {
      setState(() {
        _currentPage = bounded;
        _annotationPage = bounded;
      });
    }
    _schedulePreferenceSave();
  }

  Future<void> _showHalfBoundary(int outgoingPage) async {
    if (outgoingPage >= _totalPages) return;
    final pageRect = _pdfController.layout.pageLayouts[outgoingPage - 1];
    final zoom = (_pdfController.viewSize.width - 16) / pageRect.width;
    final ratio = _preferences.splitRatioForPage(outgoingPage);
    final boundaryY = pageRect.bottom + _pdfController.params.margin / 2;
    final viewHeightInDocument = _pdfController.viewSize.height / zoom;
    final centerY = boundaryY + (0.5 - ratio) * viewHeightInDocument;
    _pdfController.value = _pdfController.calcMatrixFor(
      Offset(pageRect.center.dx, centerY),
      zoom: zoom,
    );
    _pdfController.setCurrentPageNumber(outgoingPage);
    if (mounted) {
      setState(() {
        _currentPage = outgoingPage;
        _annotationPage = outgoingPage;
        _showingHalfBoundary = true;
      });
    }
  }

  Future<void> _showSpread(int page) async {
    final start = scoreSpreadStart(
      page.clamp(1, _totalPages),
      firstPageOnRight: _preferences.firstPageOnRight,
    );
    final layouts = _pdfController.layout.pageLayouts;
    final firstRect = layouts[start - 1];
    final rowRects = <Rect>[firstRect];
    if (start < _totalPages) {
      final candidate = layouts[start];
      if ((candidate.center.dy - firstRect.center.dy).abs() < 1) {
        rowRects.add(candidate);
      }
    }
    var area = rowRects.reduce((a, b) => a.expandToInclude(b));
    if (_preferences.firstPageOnRight && start == 1) {
      area = Rect.fromLTWH(
        0,
        area.top,
        _pdfController.layout.documentSize.width,
        area.height,
      );
    }
    await _pdfController.goToArea(
      rect: area.inflate(_pdfController.params.margin),
      anchor: PdfPageAnchor.all,
      duration: const Duration(milliseconds: 120),
    );
    _pdfController.setCurrentPageNumber(start);
    if (mounted) {
      setState(() {
        _currentPage = start;
        _annotationPage = start;
      });
    }
    _schedulePreferenceSave();
  }

  Future<void> _applyCurrentView() async {
    if (!_pdfController.isReady || _totalPages == 0) return;
    _showingHalfBoundary = false;
    if (_effectiveLayoutMode == ScoreLayoutMode.twoPage) {
      await _showSpread(_currentPage);
    } else {
      await _showFullPage(_currentPage);
    }
  }

  void _startAutoScroll() {
    if (!_isReady) return;
    if (_preferences.layoutMode != ScoreLayoutMode.continuous) {
      _updatePreferences(
        _preferences.copyWith(layoutMode: ScoreLayoutMode.continuous),
        reapplyView: true,
      );
    }
    _autoScrollTimer?.cancel();
    _lastAutoScrollTick = DateTime.now();
    setState(() => _autoScrollRunning = true);
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _autoScrollTick(),
    );
  }

  void _autoScrollTick() {
    if (!mounted || !_pdfController.isReady || !_autoScrollRunning) return;
    final now = DateTime.now();
    final elapsed = now.difference(_lastAutoScrollTick!).inMicroseconds / 1e6;
    _lastAutoScrollTick = now;
    final visible = _pdfController.visibleRect;
    final maxCenterY =
        _pdfController.layout.documentSize.height - visible.height / 2;
    final rate = scoreAutoScrollRate(
      mode: _preferences.autoScrollPaceMode,
      visibleHeight: visible.height,
      documentHeight: _pdfController.layout.documentSize.height,
      viewportHeightsPerMinute: _preferences.autoScrollViewportHeightsPerMinute,
      durationSeconds: _preferences.autoScrollDurationSeconds,
    );
    final nextY = _pdfController.centerPosition.dy + rate * elapsed;
    if (nextY >= maxCenterY) {
      _pdfController.value = _pdfController.calcMatrixFor(
        Offset(_pdfController.centerPosition.dx, maxCenterY),
      );
      _stopAutoScroll();
      return;
    }
    _pdfController.value = _pdfController.calcMatrixFor(
      Offset(_pdfController.centerPosition.dx, nextY),
    );
  }

  void _stopAutoScroll({bool updateState = true}) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _lastAutoScrollTick = null;
    if (_autoScrollRunning) {
      _autoScrollRunning = false;
      if (updateState && mounted) setState(() {});
    }
  }

  Future<void> _enterPerformanceMode() async {
    if (_isPerformanceMode) return;
    _stopAutoScroll();
    setState(() {
      _isPerformanceMode = true;
      _performanceControlsVisible = false;
      _activeNavIndex = 1;
    });
    try {
      await Future.wait([
        _displayController.enterFullscreen(),
        _displayController.applyBrightness(_brightness),
        _screenAwakeCoordinator.setPerformanceEnabled(true),
      ]);
      _pdfController.requestFocus();
    } catch (error) {
      debugPrint('Unable to enter performance mode: $error');
    }
  }

  Future<void> _leavePerformanceMode() async {
    _stopAutoScroll();
    if (mounted) {
      setState(() {
        _isPerformanceMode = false;
        _performanceControlsVisible = false;
        _touchLocked = false;
      });
    }
    try {
      await Future.wait([
        _displayController.leaveFullscreen(),
        _screenAwakeCoordinator.setPerformanceEnabled(false),
      ]);
    } catch (error) {
      debugPrint('Unable to leave performance mode: $error');
    }
  }

  Future<void> _applyDisplayState() async {
    try {
      await Future.wait([
        _displayController.applyOrientation(_preferences.orientationMode),
        _displayController.applyBrightness(_brightness),
        if (_isPerformanceMode) _displayController.enterFullscreen(),
        if (_isPerformanceMode)
          _screenAwakeCoordinator.setPerformanceEnabled(true),
      ]);
    } catch (error) {
      debugPrint('Unable to apply score display settings: $error');
    }
  }

  Widget _buildPerformanceTouchLayer() {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            flex: 25,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _touchLocked ? null : _navigateBackward,
            ),
          ),
          Expanded(
            flex: 50,
            child: GestureDetector(
              key: const ValueKey('performance_controls_toggle'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(
                () =>
                    _performanceControlsVisible = !_performanceControlsVisible,
              ),
            ),
          ),
          Expanded(
            flex: 25,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _touchLocked ? null : _navigateForward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalPageTurnLayer() {
    return Positioned.fill(
      child: Row(
        children: [
          Expanded(
            flex: 18,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _navigateBackward,
            ),
          ),
          const Expanded(flex: 64, child: IgnorePointer()),
          Expanded(
            flex: 18,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _navigateForward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceControls(PracticeProvider practice) {
    return Positioned(
      key: const ValueKey('performance_controls'),
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: Material(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('exit_performance_mode'),
                  color: Colors.white,
                  tooltip: context.translate('exit_performance'),
                  onPressed: _leavePerformanceMode,
                  icon: const Icon(Icons.close_fullscreen_rounded),
                ),
                IconButton(
                  key: const ValueKey('toggle_touch_lock'),
                  color: _touchLocked ? Colors.amber : Colors.white,
                  tooltip: context.translate('touch_lock'),
                  onPressed: () => setState(() => _touchLocked = !_touchLocked),
                  icon: Icon(
                    _touchLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  ),
                ),
                IconButton(
                  key: const ValueKey('toggle_auto_scroll'),
                  color: _autoScrollRunning ? Colors.amber : Colors.white,
                  tooltip: context.translate('auto_scroll'),
                  onPressed: _autoScrollRunning
                      ? _stopAutoScroll
                      : _startAutoScroll,
                  icon: Icon(
                    _autoScrollRunning
                        ? Icons.pause_circle_rounded
                        : Icons.slow_motion_video_rounded,
                  ),
                ),
                IconButton(
                  color: practice.metronomeOn ? Colors.amber : Colors.white,
                  tooltip: context.translate('toggle_metronome'),
                  onPressed: () =>
                      practice.toggleMetronome(practice.metronomeBpm),
                  icon: const Icon(Icons.timer_outlined),
                ),
                SizedBox(
                  width: 120,
                  child: Slider(
                    value: _brightness,
                    min: 0.1,
                    max: 1,
                    divisions: 18,
                    onChanged: _setBrightness,
                  ),
                ),
                Text(_pageLabel(), style: const TextStyle(color: Colors.white)),
                IconButton(
                  color: Colors.white,
                  tooltip: context.translate('score_display_options'),
                  onPressed: _showDisplayOptions,
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHalfPageDivider() {
    final ratio = _preferences.splitRatioForPage(_currentPage);
    final viewerHeight = _pdfController.isReady
        ? _pdfController.viewSize.height
        : MediaQuery.sizeOf(context).height;
    return Positioned(
      left: 12,
      right: 12,
      top: viewerHeight * ratio - 12,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) {
          final next = (ratio + details.delta.dy / viewerHeight).clamp(
            0.3,
            0.7,
          );
          final splits = Map<int, double>.from(_preferences.halfPageSplitRatios)
            ..[_currentPage] = next;
          _updatePreferences(
            _preferences.copyWith(halfPageSplitRatios: splits),
            reapplyView: false,
          );
          unawaited(_showHalfBoundary(_currentPage));
        },
        child: Container(
          height: 24,
          alignment: Alignment.center,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDisplayOptions() async {
    final openedFromPerformanceMode = _isPerformanceMode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor(context),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(ScoreViewPreferences next, {bool reapplyView = true}) {
            _updatePreferences(next, reapplyView: reapplyView);
            setSheetState(() {});
          }

          String layoutLabel(ScoreLayoutMode mode) => switch (mode) {
            ScoreLayoutMode.singlePage => sheetContext.translate('single_page'),
            ScoreLayoutMode.continuous => sheetContext.translate('continuous'),
            ScoreLayoutMode.halfPage => sheetContext.translate('half_page'),
            ScoreLayoutMode.twoPage => sheetContext.translate('two_pages'),
          };

          IconData layoutIcon(ScoreLayoutMode mode) => switch (mode) {
            ScoreLayoutMode.singlePage => Icons.crop_portrait_rounded,
            ScoreLayoutMode.continuous => Icons.view_stream_rounded,
            ScoreLayoutMode.halfPage => Icons.splitscreen_rounded,
            ScoreLayoutMode.twoPage => Icons.auto_stories_rounded,
          };

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    sheetContext.translate('score_display_options'),
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 18),
                  Text(sheetContext.translate('page_layout')),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ScoreLayoutMode.values
                        .map(
                          (mode) => ChoiceChip(
                            avatar: Icon(layoutIcon(mode), size: 18),
                            label: Text(layoutLabel(mode)),
                            selected: _preferences.layoutMode == mode,
                            onSelected: (_) =>
                                update(_preferences.copyWith(layoutMode: mode)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  if (_preferences.layoutMode == ScoreLayoutMode.singlePage)
                    SegmentedButton<ScoreFitMode>(
                      segments: [
                        ButtonSegment(
                          value: ScoreFitMode.fitPage,
                          label: Text(sheetContext.translate('fit_page')),
                        ),
                        ButtonSegment(
                          value: ScoreFitMode.fitWidth,
                          label: Text(sheetContext.translate('fit_width')),
                        ),
                      ],
                      selected: {_preferences.fitMode},
                      onSelectionChanged: (selection) => update(
                        _preferences.copyWith(fitMode: selection.single),
                      ),
                    ),
                  if (_preferences.layoutMode == ScoreLayoutMode.twoPage)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        sheetContext.translate('first_page_on_right'),
                      ),
                      value: _preferences.firstPageOnRight,
                      onChanged: (value) => update(
                        _preferences.copyWith(firstPageOnRight: value),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(sheetContext.translate('orientation')),
                  SegmentedButton<ScoreOrientationMode>(
                    segments: [
                      ButtonSegment(
                        value: ScoreOrientationMode.auto,
                        label: Text(sheetContext.translate('automatic')),
                      ),
                      ButtonSegment(
                        value: ScoreOrientationMode.portrait,
                        label: Text(sheetContext.translate('portrait')),
                      ),
                      ButtonSegment(
                        value: ScoreOrientationMode.landscape,
                        label: Text(sheetContext.translate('landscape')),
                      ),
                    ],
                    selected: {_preferences.orientationMode},
                    onSelectionChanged: (selection) {
                      update(
                        _preferences.copyWith(
                          orientationMode: selection.single,
                        ),
                        reapplyView: false,
                      );
                      unawaited(
                        _displayController.applyOrientation(selection.single),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(sheetContext.translate('score_colors')),
                  SegmentedButton<ScoreColorMode>(
                    segments: [
                      ButtonSegment(
                        value: ScoreColorMode.normal,
                        label: Text(sheetContext.translate('normal')),
                      ),
                      ButtonSegment(
                        value: ScoreColorMode.sepia,
                        label: Text(sheetContext.translate('sepia')),
                      ),
                      ButtonSegment(
                        value: ScoreColorMode.inverted,
                        label: Text(sheetContext.translate('inverted')),
                      ),
                    ],
                    selected: {_preferences.colorMode},
                    onSelectionChanged: (selection) => update(
                      _preferences.copyWith(colorMode: selection.single),
                      reapplyView: false,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(sheetContext.translate('brightness')),
                  Slider(
                    value: _brightness,
                    min: 0.1,
                    max: 1,
                    divisions: 18,
                    onChanged: (value) {
                      _setBrightness(value);
                      setSheetState(() {});
                    },
                  ),
                  const Divider(height: 28),
                  Text(sheetContext.translate('auto_scroll')),
                  SegmentedButton<AutoScrollPaceMode>(
                    segments: [
                      ButtonSegment(
                        value: AutoScrollPaceMode.speed,
                        label: Text(sheetContext.translate('speed')),
                      ),
                      ButtonSegment(
                        value: AutoScrollPaceMode.duration,
                        label: Text(sheetContext.translate('duration')),
                      ),
                    ],
                    selected: {_preferences.autoScrollPaceMode},
                    onSelectionChanged: (selection) => update(
                      _preferences.copyWith(
                        autoScrollPaceMode: selection.single,
                      ),
                      reapplyView: false,
                    ),
                  ),
                  Slider(
                    value:
                        _preferences.autoScrollPaceMode ==
                            AutoScrollPaceMode.speed
                        ? _preferences.autoScrollViewportHeightsPerMinute
                        : _preferences.autoScrollDurationSeconds / 60.0,
                    min:
                        _preferences.autoScrollPaceMode ==
                            AutoScrollPaceMode.speed
                        ? 0.25
                        : 1,
                    max:
                        _preferences.autoScrollPaceMode ==
                            AutoScrollPaceMode.speed
                        ? 3
                        : 240,
                    divisions:
                        _preferences.autoScrollPaceMode ==
                            AutoScrollPaceMode.speed
                        ? 11
                        : 239,
                    onChanged: (value) => update(
                      _preferences.autoScrollPaceMode ==
                              AutoScrollPaceMode.speed
                          ? _preferences.copyWith(
                              autoScrollViewportHeightsPerMinute: value,
                            )
                          : _preferences.copyWith(
                              autoScrollDurationSeconds: value.round() * 60,
                            ),
                      reapplyView: false,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(_showFullPage(1));
                          },
                          icon: const Icon(Icons.first_page_rounded),
                          label: Text(sheetContext.translate('start_page_one')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _autoScrollRunning
                                ? _stopAutoScroll()
                                : _startAutoScroll();
                          },
                          icon: Icon(
                            _autoScrollRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          label: Text(
                            sheetContext.translate(
                              _autoScrollRunning
                                  ? 'pause_auto_scroll'
                                  : 'start_auto_scroll',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(sheetContext.translate('page')),
                      Expanded(
                        child: Slider(
                          value: _currentPage.toDouble().clamp(
                            1,
                            math.max(1, _totalPages).toDouble(),
                          ),
                          min: 1,
                          max: math.max(1, _totalPages).toDouble(),
                          divisions: _totalPages > 1 ? _totalPages - 1 : null,
                          label: _currentPage.toString(),
                          onChanged: _totalPages > 1
                              ? (value) {
                                  setState(() {
                                    _currentPage = value.round();
                                    _annotationPage = _currentPage;
                                  });
                                  setSheetState(() {});
                                }
                              : null,
                          onChangeEnd: (value) =>
                              unawaited(_showFullPage(value.round())),
                        ),
                      ),
                      Text(_pageLabel()),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (openedFromPerformanceMode && _isPerformanceMode && mounted) {
      setState(() => _performanceControlsVisible = false);
    }
  }

  void _updatePreferences(
    ScoreViewPreferences next, {
    required bool reapplyView,
  }) {
    final layoutChanged =
        next.layoutMode != _preferences.layoutMode ||
        next.firstPageOnRight != _preferences.firstPageOnRight;
    setState(() {
      _preferences = next;
      if (next.layoutMode != ScoreLayoutMode.halfPage) {
        _showingHalfBoundary = false;
      }
    });
    _schedulePreferenceSave(immediate: true);
    if (layoutChanged) _pdfController.invalidate();
    if (reapplyView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_applyCurrentView());
      });
    }
  }

  void _schedulePreferenceSave({bool immediate = false}) {
    if (!_preferencesLoaded) return;
    _preferenceDebounce?.cancel();
    void save() {
      final snapshot = _preferences.copyWith(lastPage: _currentPage);
      _preferences = snapshot;
      _preferenceSaveQueue = _preferenceSaveQueue
          .then((_) => _preferencesRepository.save(snapshot))
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('Score view preferences could not be saved: $error');
          });
    }

    if (immediate) {
      save();
    } else {
      _preferenceDebounce = Timer(const Duration(milliseconds: 300), save);
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final loaded = await _preferencesRepository.load(
        pieceId: widget.pieceId,
        sourcePath: widget.pdfPath,
      );
      if (!mounted) return;
      setState(() {
        _preferences = loaded;
        _currentPage = loaded.lastPage;
        _annotationPage = loaded.lastPage;
        _preferencesLoaded = true;
      });
      await _applyDisplayState();
    } catch (error) {
      debugPrint('Score view preferences could not be loaded: $error');
      if (mounted) setState(() => _preferencesLoaded = true);
    }
  }

  void _setBrightness(double value) {
    setState(() => _brightness = value.clamp(0.1, 1.0));
    unawaited(_displayController.applyBrightness(_brightness));
    unawaited(DatabaseService().setPerformanceBrightness(_brightness));
  }

  String _pageLabel() {
    return scorePageLabel(
      page: _currentPage,
      pageCount: _totalPages,
      layoutMode: _effectiveLayoutMode,
      firstPageOnRight: _preferences.firstPageOnRight,
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 24,
      right: 24,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            _pageLabel(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnotationNotice() {
    return Positioned(
      top: 12,
      left: 24,
      right: 24,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              context.translate('annotations_saved_automatically'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetronomeBadge(PracticeProvider practice) {
    return Positioned(
      bottom: 24,
      left: 24,
      child: ActionChip(
        avatar: Icon(
          Icons.timer_outlined,
          color: practice.metronomeOn
              ? AppTheme.accentColor(context)
              : AppTheme.textSecondaryColor(context),
        ),
        label: Text('${practice.metronomeBpm} BPM'),
        onPressed: () => practice.toggleMetronome(widget.pieceBpm),
      ),
    );
  }

  Widget _buildBottomNavigation(PracticeProvider practice) {
    return BottomNavigationBar(
      currentIndex: _activeNavIndex,
      onTap: (index) {
        if (index == 0) {
          _showMetronomeSettings(practice);
        } else {
          setState(() => _activeNavIndex = index);
        }
      },
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.timer_outlined),
          label: context.translate('visual_metronome'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.menu_book_rounded),
          label: context.translate('score_view'),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.edit_note_rounded),
          label: context.translate('annotate_score'),
        ),
      ],
    );
  }

  Widget _buildPageAnnotationOverlay(
    BuildContext overlayContext,
    PdfPage page,
  ) {
    final strokes = _strokesByPage[page.pageNumber] ?? const <PdfInkStroke>[];
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          return IgnorePointer(
            ignoring:
                _isPerformanceMode ||
                _activeNavIndex != 2 ||
                !_annotationsLoaded,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) => _startStroke(
                page.pageNumber,
                details.localPosition,
                size,
                AppTheme.accentColor(overlayContext).toARGB32(),
              ),
              onPanUpdate: (details) =>
                  _extendStroke(page.pageNumber, details.localPosition, size),
              onPanEnd: (_) => _queueAnnotationSave(),
              onPanCancel: _queueAnnotationSave,
              child: CustomPaint(
                painter: AnnotationPainter(
                  strokes: List.of(strokes),
                  pageWidthInPdfPoints: page.width,
                ),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );
  }

  PdfAnnotationPoint _normalizePoint(Offset point, Size size) {
    return PdfAnnotationPoint(
      x: (point.dx / size.width).clamp(0.0, 1.0),
      y: (point.dy / size.height).clamp(0.0, 1.0),
    );
  }

  void _startStroke(int pageNumber, Offset point, Size size, int colorArgb) {
    if (size.isEmpty) return;
    setState(() {
      _annotationPage = pageNumber;
      _strokesByPage
          .putIfAbsent(pageNumber, () => [])
          .add(
            PdfInkStroke(
              points: [_normalizePoint(point, size)],
              colorArgb: colorArgb,
            ),
          );
    });
  }

  void _extendStroke(int pageNumber, Offset point, Size size) {
    if (size.isEmpty) return;
    final strokes = _strokesByPage[pageNumber];
    if (strokes == null || strokes.isEmpty) return;
    setState(() {
      final index = strokes.length - 1;
      strokes[index] = strokes[index].copyWith(
        points: [...strokes[index].points, _normalizePoint(point, size)],
      );
    });
  }

  Future<void> _loadAnnotations() async {
    try {
      final document = await _annotationRepository.load(
        pieceId: widget.pieceId,
        sourcePath: widget.pdfPath,
      );
      if (!mounted) return;
      setState(() {
        _strokesByPage
          ..clear()
          ..addEntries(
            document.pages.entries.map(
              (entry) => MapEntry(entry.key, List.of(entry.value)),
            ),
          );
        _annotationsLoaded = true;
      });
    } catch (error) {
      debugPrint('PDF annotations could not be loaded: $error');
      if (!mounted) return;
      setState(() => _annotationsLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('annotations_load_error'))),
      );
    }
  }

  PdfAnnotationDocument _annotationSnapshot() => PdfAnnotationDocument(
    pieceId: widget.pieceId,
    sourcePath: widget.pdfPath,
    pages: {
      for (final entry in _strokesByPage.entries)
        if (entry.value.isNotEmpty) entry.key: List.of(entry.value),
    },
  );

  void _queueAnnotationSave() {
    final snapshot = _annotationSnapshot();
    _annotationSaveQueue = _annotationSaveQueue
        .then((_) => _annotationRepository.save(snapshot))
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('PDF annotations could not be saved: $error');
          if (!mounted || _saveErrorShown) return;
          _saveErrorShown = true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('annotations_save_error')),
            ),
          );
        });
  }

  Future<void> _confirmClearCurrentPage() async {
    final pageNumber = _annotationPage;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.translate('clear_annotations_title')),
        content: Text(dialogContext.translate('clear_annotations_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.translate('clear')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _strokesByPage.remove(pageNumber));
    _queueAnnotationSave();
  }

  Future<void> _exportAnnotatedPdf() async {
    if (_isExporting || !_hasAnnotations) return;
    setState(() => _isExporting = true);
    try {
      final Uint8List bytes = await _annotatedPdfExporter.build(
        sourcePath: widget.pdfPath,
        annotations: _annotationSnapshot(),
      );
      if (!mounted) return;
      final safeTitle = widget.pieceTitle
          .trim()
          .replaceAll(RegExp(r'[^a-zA-Z0-9 ._-]'), '_')
          .replaceAll(RegExp(r'\s+'), '-');
      final output = await FilePicker.saveFile(
        dialogTitle: context.translate('export_annotated_pdf'),
        fileName: '${safeTitle.isEmpty ? 'score' : safeTitle}-annotated.pdf',
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      if (!kIsWeb && output == null) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.translate('annotated_pdf_exported'))),
        );
      }
    } catch (error) {
      debugPrint('Annotated PDF export failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('annotated_pdf_export_error')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showMetronomeSettings(PracticeProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sheetContext.translate('visual_metronome'),
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: provider.metronomeBpm > 40
                          ? () {
                              provider.setMetronomeBpm(
                                provider.metronomeBpm - 1,
                              );
                              setSheetState(() {});
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    Expanded(
                      child: Slider(
                        min: 40,
                        max: 240,
                        value: provider.metronomeBpm.toDouble(),
                        onChanged: (value) {
                          provider.setMetronomeBpm(value.round());
                          setSheetState(() {});
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: provider.metronomeBpm < 240
                          ? () {
                              provider.setMetronomeBpm(
                                provider.metronomeBpm + 1,
                              );
                              setSheetState(() {});
                            }
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
                Text(
                  '${provider.metronomeBpm} BPM',
                  style: Theme.of(sheetContext).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    provider.toggleMetronome(provider.metronomeBpm);
                    setSheetState(() {});
                  },
                  child: Text(
                    sheetContext.translate(
                      provider.metronomeOn
                          ? 'stop_metronome'
                          : 'start_metronome',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnnotationPainter extends CustomPainter {
  final List<PdfInkStroke> strokes;
  final double pageWidthInPdfPoints;

  const AnnotationPainter({
    required this.strokes,
    required this.pageWidthInPdfPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageWidthInPdfPoints <= 0) return;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(stroke.colorArgb)
        ..strokeWidth =
            stroke.widthInPdfPoints * size.width / pageWidthInPdfPoints
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final points = stroke.points
          .map((point) => Offset(point.x * size.width, point.y * size.height))
          .toList(growable: false);
      if (points.length == 1) {
        canvas.drawPoints(PointMode.points, points, paint);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.pageWidthInPdfPoints != pageWidthInPdfPoints;
}
