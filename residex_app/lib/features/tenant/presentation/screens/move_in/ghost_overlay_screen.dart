import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/models/move_in_photo.dart';
import '../../../../../core/services/photo_storage_service.dart';
import '../../../../../core/services/gemini_service.dart';


enum _GhostStep { select, camera, analyzing, report }



class GhostOverlayScreen extends StatefulWidget {
  const GhostOverlayScreen({super.key});

  @override
  State<GhostOverlayScreen> createState() => _GhostOverlayScreenState();
}

class _GhostOverlayScreenState extends State<GhostOverlayScreen>
    with SingleTickerProviderStateMixin {

  // ── Navigation state ──
  _GhostStep _step = _GhostStep.select;

  // ── Area iteration ──
  List<MoveInPhoto> _moveInPhotos = [];
  bool _loadingPhotos = true;
  int _currentAreaIndex = 0;

  // ── Camera ──
  CameraController? _cameraController;
  bool _cameraReady = false;
  double _ghostOpacity = 0.4;

  // ── Results ──
  // Accumulate findings across all areas
  final List<Map<String, dynamic>> _allAreaResults = [];
  bool _analyzing = false;

  // ── Animations ──
  late AnimationController _spinController;

  final _photoService = PhotoStorageService();
  final _geminiService = GeminiService();

  MoveInPhoto get _currentArea => _moveInPhotos[_currentAreaIndex];

  @override
  void initState() {
    super.initState();
    _spinController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();
    _loadPhotos();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    final photos = await _photoService.getMoveInPhotos();
    if (mounted) setState(() { _moveInPhotos = photos; _loadingPhotos = false; });
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    if (mounted) setState(() => _cameraReady = true);
  }

  void _startScan() {
    setState(() {
      _currentAreaIndex = 0;
      _allAreaResults.clear();
      _step = _GhostStep.camera;
    });
    _initCamera();
  }

  Future<void> _captureAndAnalyze() async {
    if (!_cameraReady || _analyzing) return;
    setState(() => _analyzing = true);

    // Capture photo from live camera
    final XFile photo = await _cameraController!.takePicture();
    final currentBytes = await photo.readAsBytes();
    final moveInBytes = await File(_currentArea.filePath).readAsBytes();

    // Switch to analyzing screen
    setState(() { _step = _GhostStep.analyzing; });

    // Call Gemini Vision
    try {
      final raw = await _geminiService.analyzePropertyCondition(
        areaName: _currentArea.areaName,
        moveInBytes: moveInBytes,
        currentBytes: currentBytes,
      );
      final cleaned = raw.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final result = jsonDecode(cleaned) as Map<String, dynamic>;

      final baselineValid = result['baselineValid'] as bool? ?? false;
      final currentValid = result['currentValid'] as bool? ?? false;
      final sameArea = result['sameArea'] as bool? ?? false;
      final validationError = result['validationError'] as String?;

      if (!baselineValid || !currentValid || !sameArea) {
        // Fraud / wrong area detected — do NOT proceed silently
        _allAreaResults.add({
          'areaName': _currentArea.areaName,
          'validationFailed': true,
          'validationError': validationError ?? 'Photo does not match expected area.',
          'matchPercent': 0,
          'findings': [
            {
              'severity': 'critical',
              'title': 'Invalid Photo Submitted',
              'description': validationError ?? 'The submitted photo does not appear to show ${_currentArea.areaName}. This has been flagged.',
            }
          ],
          'estimatedDeductionMin': 0,
          'estimatedDeductionMax': 0,
          'wearAndTearNote': 'Photo could not be verified. Landlord review required.',
        });
      } else {
        _allAreaResults.add({
          'areaName': _currentArea.areaName,
          'moveInPath': _currentArea.filePath,
          'currentBytes': currentBytes,
          ...result,
        });
      }
    } catch (e) {
      _allAreaResults.add({
        'areaName': _currentArea.areaName,
        'validationFailed': true,
        'validationError': 'Analysis failed — photo could not be processed.',
        'matchPercent': 0,
        'findings': [
          {
            'severity': 'critical',
            'title': 'Scan Failed',
            'description': 'The photo could not be analyzed. Please retake the scan for this area.',
          }
        ],
        'estimatedDeductionMin': 0,
        'estimatedDeductionMax': 0,
        'wearAndTearNote': 'Manual inspection required.',
      });
    }

    // Move to next area or finish
    if (_currentAreaIndex < _moveInPhotos.length - 1) {
      setState(() {
        _currentAreaIndex++;
        _analyzing = false;
        _step = _GhostStep.camera;
      });
    } else {
      await _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() { _analyzing = false; _step = _GhostStep.report; });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_step != _GhostStep.camera && _step != _GhostStep.analyzing)
            Positioned(
              top: 0, left: 0, right: 0, height: 500,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter, radius: 1.2,
                    colors: [AppColors.cyan500.withValues(alpha: 0.2), Colors.black],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                if (_step != _GhostStep.camera && _step != _GhostStep.analyzing)
                  _buildHeader(),
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_step == _GhostStep.select) {
                context.pop();
              } else {
                setState(() => _step = _GhostStep.select);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, size: 20, color: AppColors.slate400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_step) {
      case _GhostStep.select:    return _buildSelectView();
      case _GhostStep.camera:    return _buildCameraView();
      case _GhostStep.analyzing: return _buildAnalyzingView();
      case _GhostStep.report:    return _buildReportView();
    }
  }

  // ── SELECT VIEW ──────────────────────────────────────────────────────────

  Widget _buildSelectView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Ghost Protocol',
              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: -1)),
          const SizedBox(height: 8),
          Text('Your move-in photos will be overlaid as a ghost image. Align your camera to match, then tap to scan.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400, height: 1.5)),
          const SizedBox(height: 24),

          if (_loadingPhotos)
            const Center(child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.cyan500, strokeWidth: 2),
            ))
          else if (_moveInPhotos.isEmpty)
            _buildNoPhotosState()
          else ...[
            // Preview of areas to scan
            ..._moveInPhotos.map((photo) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAreaPreviewCard(photo),
            )),
            const SizedBox(height: 24),
            // Start button
            GestureDetector(
              onTap: _startScan,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppColors.cyan500,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.4), blurRadius: 24)],
                ),
                child: Text('START GHOST SCAN — ${_moveInPhotos.length} AREAS',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/move-in-session').then((_) => _loadPhotos()),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text('Update Baseline Photos',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAreaPreviewCard(MoveInPhoto photo) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: Image.file(File(photo.filePath), width: 80, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 80, color: AppColors.slate800,
                    child: const Icon(Icons.image, color: AppColors.slate600))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(photo.areaName,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const Icon(Icons.chevron_right, color: AppColors.slate600),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildNoPhotosState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.slate900,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.cyan500.withValues(alpha: 0.1), shape: BoxShape.circle,
              border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.photo_camera_outlined, size: 32, color: AppColors.cyan400),
          ),
          const SizedBox(height: 20),
          Text('No Baseline Photos Yet',
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Take move-in photos first so Ghost Mode can overlay them as a guide when you scan.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/move-in-session').then((_) => _loadPhotos()),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cyan500, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.3), blurRadius: 20)],
              ),
              child: Text('START MOVE-IN SESSION',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  // ── CAMERA VIEW ──────────────────────────────────────────────────────────

  Widget _buildCameraView() {
    final progress = (_currentAreaIndex + 1) / _moveInPhotos.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Live camera feed
        if (_cameraReady && _cameraController != null)
          CameraPreview(_cameraController!)
        else
          Container(color: Colors.black,
              child: const Center(child: CircularProgressIndicator(color: AppColors.cyan500, strokeWidth: 2))),

        // 2. Ghost overlay — baseline photo at reduced opacity
        Opacity(
          opacity: _ghostOpacity,
          child: Image.file(
            File(_currentArea.filePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),

        // 3. Corner brackets HUD
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Stack(children: _buildCornerBrackets()),
          ),
        ),

        // 4. Top bar: area progress + live badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16, right: 16,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back
                  GestureDetector(
                    onTap: () async {
                      await _cameraController?.dispose();
                      _cameraController = null;
                      if (mounted) setState(() { _cameraReady = false; _step = _GhostStep.select; });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, size: 20, color: Colors.white),
                    ),
                  ),
                  // Area counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text('${_currentAreaIndex + 1} / ${_moveInPhotos.length}  •  ${_currentArea.areaName}',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  // Live badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.rose500.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.rose500.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.rose400, shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text('LIVE', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan500),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),

        // 5. Rex tip bubble
        Positioned(
          top: MediaQuery.of(context).padding.top + 100,
          left: 24, right: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.cyan400),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Align your camera with the ghost image. Match the door frame position, then tap.',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white, height: 1.5)),
                ),
              ],
            ),
          ),
        ),

        // 6. Bottom controls
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black, Colors.black.withValues(alpha: 0.8), Colors.transparent],
              ),
            ),
            child: Column(
              children: [
                // ── Ghost opacity slider ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Text('GHOST', style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.slate500)),
                      Expanded(
                        child: Slider(
                          value: _ghostOpacity,
                          onChanged: (v) => setState(() => _ghostOpacity = v),
                          activeColor: AppColors.cyan400,
                          inactiveColor: AppColors.slate700,
                        ),
                      ),
                      Text('${(_ghostOpacity * 100).toInt()}%',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.cyan400)),
                    ],
                  ),
                ),
                // ── Capture button ──
                GestureDetector(
                  onTap: _analyzing ? null : _captureAndAnalyze,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4),
                    ),
                    child: Center(
                      child: Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.cyan400, shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AppColors.cyan400.withValues(alpha: 0.6), blurRadius: 30)],
                        ),
                        child: _analyzing
                            ? const Center(child: SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCornerBrackets() {
    const color = AppColors.cyan400;
    const size = 28.0;
    const thickness = 3.0;
    const radius = 10.0;

    Widget corner(bool isTop, bool isLeft) {
      return Positioned(
        top: isTop ? 0 : null,
        bottom: !isTop ? 0 : null,
        left: isLeft ? 0 : null,
        right: !isLeft ? 0 : null,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            border: Border(
              top: isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
              bottom: !isTop ? const BorderSide(color: color, width: thickness) : BorderSide.none,
              left: isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
              right: !isLeft ? const BorderSide(color: color, width: thickness) : BorderSide.none,
            ),
            borderRadius: BorderRadius.only(
              topLeft: isTop && isLeft ? const Radius.circular(radius) : Radius.zero,
              topRight: isTop && !isLeft ? const Radius.circular(radius) : Radius.zero,
              bottomLeft: !isTop && isLeft ? const Radius.circular(radius) : Radius.zero,
              bottomRight: !isTop && !isLeft ? const Radius.circular(radius) : Radius.zero,
            ),
          ),
        ),
      );
    }

    return [corner(true, true), corner(true, false), corner(false, true), corner(false, false)];
  }

  // ── ANALYZING VIEW ───────────────────────────────────────────────────────

  Widget _buildAnalyzingView() {
    return Container(
      color: AppColors.deepSpace,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center, radius: 0.8,
                  colors: [AppColors.cyan500.withValues(alpha: 0.15), AppColors.deepSpace],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 160, height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      RotationTransition(
                        turns: _spinController,
                        child: Container(
                          width: 160, height: 160,
                          decoration: const BoxDecoration(shape: BoxShape.circle),
                          child: CustomPaint(painter: _SpinArcPainter(AppColors.cyan500)),
                        ),
                      ),
                      const Icon(Icons.document_scanner, size: 48, color: AppColors.cyan400),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Text('ANALYZING ${_currentAreaIndex + 1} OF ${_moveInPhotos.length}',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(_currentArea.areaName,
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.cyan400, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Gemini Vision comparing move-in baseline...',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600,
                          letterSpacing: 1.5, color: AppColors.slate400)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── REPORT VIEW ──────────────────────────────────────────────────────────

  Widget _buildReportView() {
    // Aggregate stats
    final allFindings = _allAreaResults
        .expand((r) => (r['findings'] as List? ?? []).map((f) => Map<String, dynamic>.from(f)))
        .toList();
    final avgMatch = _allAreaResults.isEmpty ? 100
        : (_allAreaResults.map((r) => (r['matchPercent'] as num? ?? 100).toInt()).reduce((a, b) => a + b) / _allAreaResults.length).round();
    final totalDeductMin = _allAreaResults.fold<int>(0, (sum, r) => sum + ((r['estimatedDeductionMin'] as num?)?.toInt() ?? 0));
    final totalDeductMax = _allAreaResults.fold<int>(0, (sum, r) => sum + ((r['estimatedDeductionMax'] as num?)?.toInt() ?? 0));
    final criticalCount = allFindings.where((f) => f['severity'] == 'critical').length;
    final warningCount = allFindings.where((f) => f['severity'] == 'warning').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emerald500.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
            ),
            child: Text('Ghost Report Complete',
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.emerald400)),
          ),
          const SizedBox(height: 16),
          Text('Property\nCondition',
              style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1)),
          const SizedBox(height: 24),

          // Summary stats row
          Row(
            children: [
              _buildStatCard('MATCH', '$avgMatch%',
                  avgMatch >= 90 ? AppColors.emerald500 : avgMatch >= 75 ? AppColors.amber500 : AppColors.rose500),
              const SizedBox(width: 12),
              _buildStatCard('DEDUCTION', totalDeductMax == 0 ? 'RM 0' : 'RM $totalDeductMin–$totalDeductMax', AppColors.cyan500),
              const SizedBox(width: 12),
              _buildStatCard('ISSUES', '${criticalCount + warningCount}',
                  criticalCount > 0 ? AppColors.rose500 : warningCount > 0 ? AppColors.amber500 : AppColors.emerald500),
            ],
          ),

          const SizedBox(height: 24),

          // Rex summary bubble
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.slate900,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.smart_toy_outlined, size: 20, color: AppColors.cyan400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    avgMatch >= 95
                        ? 'Property is in excellent condition. Estimated RM 0 deduction. Enjoy your bond refund!'
                        : 'Property condition: $avgMatch% match with move-in state. ${criticalCount > 0 ? '$criticalCount critical issue(s) found. ' : ''}Estimated deduction: RM $totalDeductMin–$totalDeductMax.',
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, height: 1.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Per-area findings
          ...(_allAreaResults.map((areaResult) {
            final areaFindings = (areaResult['findings'] as List? ?? [])
                .map((f) => Map<String, dynamic>.from(f)).toList();
            final wearNote = areaResult['wearAndTearNote'] as String? ?? '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fraud flag banner
                  if (areaResult['validationFailed'] == true)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.rose500.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.rose500.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flag_rounded, size: 16, color: AppColors.rose400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Photo flagged — does not match expected area',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.rose400)),
                          ),
                        ],
                      ),
                    ),
                Text(areaResult['areaName'] as String,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900,
                        letterSpacing: 1, color: AppColors.slate400)),
                const SizedBox(height: 10),
                ...areaFindings.map((f) {
                  final sev = f['severity'] as String? ?? 'ok';
                  final IconData icon;
                  final Color color;
                  switch (sev) {
                    case 'critical': icon = Icons.error_rounded; color = AppColors.rose500;
                    case 'warning':  icon = Icons.warning_amber; color = AppColors.amber500;
                    default:         icon = Icons.check_circle;  color = AppColors.emerald400;
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildFinding(icon: icon, iconColor: color,
                        title: f['title'] as String? ?? '',
                        description: f['description'] as String? ?? ''),
                  );
                }),
                if (wearNote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text('⚖️  $wearNote',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate500, height: 1.5, fontStyle: FontStyle.italic)),
                  ),
              ],
            );
          })),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _startScan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text('RESCAN',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate400)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.cyan500,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.3), blurRadius: 20)],
                    ),
                    child: Text('SAVE REPORT',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinding({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(description, style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpinArcPainter extends CustomPainter {
  final Color color;
  _SpinArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromLTWH(0, 0, size.width, size.height), 0, pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
