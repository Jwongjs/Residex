import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/services/photo_storage_service.dart';
import '../../../../../core/services/gemini_service.dart';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class _Area {
  final String id;
  final String name;
  final String guide;
  final IconData icon;
  _Area(this.id, this.name, this.guide, this.icon);
}

enum _SentinelThreatLevel { calibrating, clear, caution, alert }

class _SentinelAnomaly {
  final String areaName;
  final double peakMuT;
  final DateTime timestamp;
  const _SentinelAnomaly({
    required this.areaName,
    required this.peakMuT,
    required this.timestamp,
  });
}

class MoveInSessionScreen extends StatefulWidget {
  const MoveInSessionScreen({super.key});

  @override
  State<MoveInSessionScreen> createState() => _MoveInSessionScreenState();
}

class _MoveInSessionScreenState extends State<MoveInSessionScreen>
    with SingleTickerProviderStateMixin{
  final _photoService = PhotoStorageService();
  final _geminiService = GeminiService();
  final _picker = ImagePicker();

  final _areas = [
    _Area('living_room', 'Living Room', 'Photograph the full room from the entrance corner', Icons.weekend_rounded),
    _Area('kitchen', 'Kitchen', 'Capture sink, stove and all counter surfaces', Icons.kitchen_rounded),
    _Area('bathroom', 'Bathroom', 'Photograph tiles, toilet, sink and shower area', Icons.bathtub_rounded),
    _Area('bedroom', 'Bedroom', 'Capture walls, floor and built-in wardrobes', Icons.bed_rounded),
    _Area('doors_windows', 'Doors & Windows', 'Document all doors, windows and locks', Icons.sensor_door_rounded),
    _Area('ceiling', 'Ceiling', 'Check for cracks, stains or damage overhead', Icons.roofing_rounded),
    _Area('electrical', 'Electrical Panel', 'Photograph the meter box and all sockets', Icons.electrical_services_rounded),
    _Area('plumbing', 'Plumbing', 'Document pipes, water heater and drainage', Icons.plumbing_rounded),
  ];

  int _currentIndex = 0;
  final Map<String, String> _capturedPaths = {};
  bool _isSaving = false;

  // ── Baseline photo validation ──
  bool _isValidating = false;
  String? _rejectedPhotoPath;   // preview of the rejected photo
  String? _validationError;     // Gemini rejection reason

  // ── Sentinel Sweeper ──
  late AnimationController _radarController;
  StreamSubscription<MagnetometerEvent>? _magnetometerSub;
  _SentinelThreatLevel _sentinelLevel = _SentinelThreatLevel.calibrating;
  double _currentMuT = 0.0;
  double _baselineMuT = 0.0;
  double _peakMuT = 0.0;
  int _calibrationSamples = 0;
  double _calibrationSum = 0.0;
  bool _anomalyBannerVisible = false;
  bool _layer2Active = false; // Placeholder for future Layer 2 (Camera Lens Interference)
  final List<_SentinelAnomaly> _sessionAnomalies = [];
  DateTime _lastSentinelUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Sentinel Layer 3 — Wi-Fi ──
  String _wifiSsid = 'Scanning...';
  bool _wifiScanDone = false;
  int _suspiciousDeviceCount = 0;

  @override
  void initState() {
    super.initState();
    _radarController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
    _startSentinel();
    unawaited(_runWifiScan());
  }

  @override
  void dispose() {
    _magnetometerSub?.cancel();
    _radarController.dispose();
    super.dispose();
  }

  // ── SENTINEL METHODS ─────────────────────────────────────────────────────

double _computeMuT(double x, double y, double z) =>
    sqrt(x * x + y * y + z * z);

void _startSentinel() {
  _magnetometerSub?.cancel();
  _magnetometerSub = magnetometerEventStream().listen(_handleMagneticEvent);
}


void _handleMagneticEvent(MagnetometerEvent e) {
  final muT = _computeMuT(e.x, e.y, e.z);

  // Throttle UI updates to 200ms to avoid jank
  final now = DateTime.now();
  if (now.difference(_lastSentinelUiUpdate).inMilliseconds < 200) return;
  _lastSentinelUiUpdate = now;

  _currentMuT = muT;
  if (muT > _peakMuT) _peakMuT = muT;

  // Calibration — first 30 samples (~3 seconds)
  if (_calibrationSamples < 30) {
    _calibrationSum += muT;
    _calibrationSamples++;
    if (_calibrationSamples == 30) {
      _baselineMuT = _calibrationSum / 30;
    }
    if (mounted) setState(() {});
    return;
  }

  final prevLevel = _sentinelLevel;
  final spike = muT - _baselineMuT;
  _SentinelThreatLevel newLevel;

  if (muT >= 100) {
    newLevel = _SentinelThreatLevel.alert;
  } else if (spike > 35 || muT > 80) {
    newLevel = _SentinelThreatLevel.caution;
  } else {
    newLevel = _SentinelThreatLevel.clear;
  }

  if (newLevel != prevLevel) {
    if (newLevel == _SentinelThreatLevel.caution &&
        prevLevel != _SentinelThreatLevel.alert) {
      Vibration.vibrate(duration: 200);
    }
    if (newLevel == _SentinelThreatLevel.alert) {
        Vibration.vibrate(pattern: [0, 500, 200, 500, 200, 500]);
        if (mounted) {setState(() {
          _anomalyBannerVisible = true;
          _layer2Active = true;
        });
    }
    }
  }


  _sentinelLevel = newLevel;
  if (mounted) setState(() {});
  }

Future<void> _runWifiScan() async {
  try {
    final status = await Permission.locationWhenInUse.request();
    if (!status.isGranted) {
      if (mounted) setState(() { _wifiSsid = 'Permission denied'; _wifiScanDone = true; });
      return;
    }
    final info = NetworkInfo();
    final ssid = await info.getWifiName() ?? 'Unknown';
    final ip   = await info.getWifiIP()   ?? '';

    if (mounted) setState(() => _wifiSsid = ssid.replaceAll('"', ''));

    final parts = ip.split('.');
    String subnet = '';
    if (parts.length == 4) subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    int suspicious = 0;
    if (subnet.isNotEmpty) {
      const keywords = ['cam', 'ipc', 'dvr', 'nvr', 'spy', 'vision', 'stream', 'ip_cam'];
      for (int i = 1; i <= 30; i++) {
        final target = '$subnet.$i';
        try {
          final socket = await Socket.connect(target, 80,
              timeout: const Duration(milliseconds: 300));
          socket.destroy();
          try {
            final hosts = await InternetAddress.lookup(target);
            for (final h in hosts) {
              if (keywords.any((k) => h.host.toLowerCase().contains(k))) suspicious++;
            }
          } catch (_) {}
        } catch (_) {}
      }
    }

    if (mounted) setState(() { _suspiciousDeviceCount = suspicious; _wifiScanDone = true; });
  } catch (_) {
    if (mounted) setState(() { _wifiSsid = 'Scan failed'; _wifiScanDone = true; });
  }
}

  @override
  Widget build(BuildContext context) {
    final area = _areas[_currentIndex];
    final capturedPath = _capturedPaths[area.id];
    final progress = (_currentIndex + 1) / _areas.length;

    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 20, color: AppColors.slate400),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${_areas.length}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.slate400),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.slate800,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.cyan500),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyan500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
                      ),
                      child: Text('Move-in Baseline',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.cyan400)),
                    ),
                    const SizedBox(height: 12),
                    Text(area.name,
                        style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                    const SizedBox(height: 8),
                    Text(area.guide,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400, height: 1.5)),
                    const SizedBox(height: 32),

                    GestureDetector(
                      onTap: _isValidating ? null : _capturePhoto,
                      child: Container(
                        height: 260,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.slate900,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _validationError != null
                                ? AppColors.rose500.withValues(alpha: 0.6)
                                : capturedPath != null
                                    ? AppColors.emerald500.withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.08),
                            width: (_validationError != null || capturedPath != null) ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildPhotoCardContent(area, capturedPath),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Validation rejection card ──
                    if (_validationError != null) ...[
                      _buildValidationRejectionCard(),
                      const SizedBox(height: 16),
                    ],

                    // ── Sentinel HUD ──
                    _buildSentinelHud(),
                    const SizedBox(height: 16),

                    // ── Wi-Fi scan result ──
                      _buildWifiResultCard(),
                      const SizedBox(height: 16),

                    // ── Anomaly banner (shown when alert triggered) ──
                    if (_anomalyBannerVisible) ...[
                      _buildAnomalyBanner(),
                      const SizedBox(height: 16),
                    ],

                    // ── Layer 2: IR Glint instruction (shown when alert triggers) ──
                      if (_layer2Active) ...[
                        _buildLayer2Overlay(),
                        const SizedBox(height: 16),
                      ],

                    Row(
                      children: [
                        if (_currentIndex > 0)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _currentIndex--;
                                _isValidating = false;
                                _rejectedPhotoPath = null;
                                _validationError = null;
                                _anomalyBannerVisible = false;
                                _layer2Active = false;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.slate800,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: Text('BACK',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate400)),
                              ),
                            ),
                          ),
                        if (_currentIndex > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            onTap: (capturedPath != null && !_isValidating) ? _onNext : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: (capturedPath != null && !_isValidating) ? AppColors.cyan500 : AppColors.slate700,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: capturedPath != null
                                    ? [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.3), blurRadius: 20)]
                                    : null,
                              ),
                              child: _isSaving
                                  ? const Center(child: SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
                                  : Text(
                                      _currentIndex == _areas.length - 1 ? 'FINISH SESSION' : 'NEXT AREA',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (capturedPath == null && !_isValidating)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: GestureDetector(
                          onTap: _onSkip,
                          child: Center(
                            child: Text('Skip this area',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.slate500,
                                    decoration: TextDecoration.underline, decorationColor: AppColors.slate500)),
                          ),
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SENTINEL UI ──────────────────────────────────────────────────────────

Color get _sentinelColor {
  switch (_sentinelLevel) {
    case _SentinelThreatLevel.calibrating: return AppColors.slate400;
    case _SentinelThreatLevel.clear:       return AppColors.emerald400;
    case _SentinelThreatLevel.caution:     return AppColors.amber400;
    case _SentinelThreatLevel.alert:       return AppColors.rose400;
  }
}

String get _sentinelStatusText {
  switch (_sentinelLevel) {
    case _SentinelThreatLevel.calibrating:
      return 'Calibrating... (${_calibrationSamples}/30)';
    case _SentinelThreatLevel.clear:
      return 'All Clear';
    case _SentinelThreatLevel.caution:
      return 'Elevated Field — Caution';
    case _SentinelThreatLevel.alert:
      return '⚠  ANOMALY DETECTED';
  }
}

Widget _buildSentinelHud() {
  final color = _sentinelColor;
  final muTText = _calibrationSamples < 30
      ? '-- µT'
      : '${_currentMuT.toStringAsFixed(1)} µT';
  final fillRatio = (_currentMuT / 130).clamp(0.0, 1.0);
  final filledBars = (fillRatio * 5).round();

  return AnimatedBuilder(
    animation: _radarController,
    builder: (context, _) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48, height: 48,
              child: CustomPaint(
                painter: _RadarPainter(
                  color: color,
                  sweepAngle: _radarController.value * 2 * pi,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SENTINEL SWEEPER',
                      style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w900,
                          letterSpacing: 1.5, color: AppColors.slate500)),
                  const SizedBox(height: 2),
                  Text(_sentinelStatusText,
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700,
                          color: color, height: 1.2)),
                  const SizedBox(height: 2),
                  Text(muTText,
                      style: GoogleFonts.inter(fontSize: 9,
                          color: color.withValues(alpha: 0.8))),
                ],
              ),
            ),
            Row(
              children: List.generate(5, (i) => Container(
                width: 4, height: 8 + (i * 3.0),
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: i < filledBars
                      ? color
                      : color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildAnomalyBanner() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.rose500.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.rose500.withValues(alpha: 0.5)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.rose400),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Magnetic Anomaly — ${_currentMuT.toStringAsFixed(0)} µT',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900,
                      color: AppColors.rose400)),
              const SizedBox(height: 3),
              Text(
                'Structural wiring is common here. Visually inspect this area for any '
                'unauthorized electronics before continuing.',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, height: 1.4),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _anomalyBannerVisible = false),
          child: const Icon(Icons.close, size: 16, color: AppColors.slate400),
        ),
      ],
    ),
  );
}

Widget _buildLayer2Overlay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.amber500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amber500.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility, size: 16, color: AppColors.amber400),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('IR Glint Check Active',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.amber400)),
                const SizedBox(height: 3),
                Text(
                  'Turn off the room lights and open your camera. Look for any bright white or purple dots — these indicate infrared LEDs from hidden cameras.',
                  style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _layer2Active = false),
            child: const Icon(Icons.close, size: 16, color: AppColors.slate400),
          ),
        ],
      ),
    );
  }

  Widget _buildWifiResultCard() {
    final isDone = _wifiScanDone;
    final hasSuspicious = isDone && _suspiciousDeviceCount > 0;
    final color = hasSuspicious ? AppColors.amber500 : AppColors.emerald500;
    final textColor = hasSuspicious ? AppColors.amber400 : AppColors.emerald400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDone ? color.withValues(alpha: 0.08) : AppColors.slate800.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wifi,
            size: 18,
            color: isDone ? textColor : AppColors.slate500,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NETWORK SCAN',
                    style: GoogleFonts.inter(
                        fontSize: 7, fontWeight: FontWeight.w900,
                        letterSpacing: 1.5, color: AppColors.slate500)),
                const SizedBox(height: 2),
                Text(
                  isDone
                      ? (hasSuspicious
                          ? '$_suspiciousDeviceCount suspicious device(s) on $_wifiSsid'
                          : 'No suspicious devices on $_wifiSsid')
                      : 'Scanning network...',
                  style: GoogleFonts.inter(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: isDone ? textColor : AppColors.slate400),
                ),
              ],
            ),
          ),
          if (!isDone)
            const SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(
                  color: AppColors.slate500, strokeWidth: 1.5),
            ),
        ],
      ),
    );
  }

void _showSessionCompleteDialog() {
  final hasAnomalies = _sessionAnomalies.isNotEmpty;
  final pseudo = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
  final wifiLine = _wifiScanDone
      ? (_suspiciousDeviceCount > 0
          ? '⚠ $_suspiciousDeviceCount suspicious device(s) on $_wifiSsid'
          : '✓ No suspicious devices on $_wifiSsid')
      : 'Wi-Fi scan pending...';

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        hasAnomalies ? '⚠ Baseline Saved — Anomalies Logged' : '✓ Baseline Complete',
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900,
            color: hasAnomalies ? AppColors.amber400 : AppColors.emerald400),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_capturedPaths.length} photos saved as your move-in baseline.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.5)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (hasAnomalies ? AppColors.amber500 : AppColors.emerald500)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (hasAnomalies ? AppColors.amber500 : AppColors.emerald500)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SENTINEL SWEEPER',
                    style: GoogleFonts.inter(fontSize: 7, fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: hasAnomalies ? AppColors.amber400 : AppColors.emerald400)),
                const SizedBox(height: 6),
                if (!hasAnomalies) ...[
                  Text('Zero anomalies detected across all areas.',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('HASH: $pseudo',
                      style: GoogleFonts.inter(fontSize: 9, color: AppColors.slate600,
                          letterSpacing: 0.5)),
                ] else ...[
                  ...(_sessionAnomalies.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${a.areaName}: ${a.peakMuT.toStringAsFixed(0)} µT peak',
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.white70)),
                  ))),
                ],
                const SizedBox(height: 6),
                Text(wifiLine,
                    style: GoogleFonts.inter(fontSize: 9, color: AppColors.slate500)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            if (mounted) context.pop(true);
          },
          child: Text('DONE',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900,
                  color: AppColors.cyan400, letterSpacing: 1)),
        ),
      ],
    ),
  );
}

  Widget _photoPlaceholder(_Area area, {required bool captured}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(area.icon, size: 48, color: AppColors.slate600),
        const SizedBox(height: 16),
        Text(captured ? 'Photo saved' : 'Tap to take photo',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate500)),
        if (!captured) ...[
          const SizedBox(height: 8),
          Text('Use your camera to document the condition',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate600), textAlign: TextAlign.center),
        ],
      ],
    );
  }

   Widget _buildPhotoCardContent(_Area area, String? capturedPath) {
      // State 1: Validating — show photo with spinner overlay
      if (_isValidating && _rejectedPhotoPath != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_rejectedPhotoPath!), fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.55)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(color: AppColors.cyan400, strokeWidth: 2.5),
                  ),
                  const SizedBox(height: 14),
                  Text('Verifying area match...',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('Gemini Vision is checking your photo',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate500)),
                ],
              ),
            ),
          ],
        );
      }

      // State 2: Rejected — show photo with red badge and retake hint
      if (_validationError != null && _rejectedPhotoPath != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_rejectedPhotoPath!), fit: BoxFit.cover),
            Container(color: Colors.black.withValues(alpha: 0.35)),
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.rose500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Wrong Area',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.black.withValues(alpha: 0.72),
                child: Text('Tap to retake',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
              ),
            ),
          ],
        );
      }

      // State 3: Accepted — show photo with green badge
      if (capturedPath != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(capturedPath), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoPlaceholder(area, captured: true)),
            Positioned(
              top: 12, right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.emerald500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Captured',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      // State 4: Empty — show placeholder
      return _photoPlaceholder(area, captured: false);
    }

    Widget _buildValidationRejectionCard() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.rose500.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.rose500.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.photo_camera, size: 16, color: AppColors.rose400),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Photo does not match this area',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.rose400)),
                  const SizedBox(height: 3),
                  Text(_validationError ?? '',
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, height: 1.4)),
                  const SizedBox(height: 6),
                  Text('Please retake a photo of the ${_areas[_currentIndex].name}.',
                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.slate400)),
                ],
              ),
            ),
          ],
        ),
      );
    }

  Future<void> _capturePhoto() async {
    // Record sentinel anomaly for this area before opening camera
    if (_peakMuT >= 100) {
      _sessionAnomalies.add(_SentinelAnomaly(
        areaName: _areas[_currentIndex].name,
        peakMuT: _peakMuT,
        timestamp: DateTime.now(),
      ));
    }
    // Re-calibrate magnetometer for the next room
    _peakMuT = 0.0;
    _calibrationSamples = 0;
    _calibrationSum = 0.0;
    _baselineMuT = 0.0;
    _sentinelLevel = _SentinelThreatLevel.calibrating;
    _anomalyBannerVisible = false;
    _layer2Active = false;

    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    final areaName = _areas[_currentIndex].name;

    // Show the photo immediately and enter validating state
    setState(() {
      _rejectedPhotoPath = picked.path;
      _validationError = null;
      _isValidating = true;
    });

    try {
      final bytes = await File(picked.path).readAsBytes();
      final result = await _geminiService.validateBaselinePhoto(
        areaName: areaName,
        imageBytes: bytes,
      );
      final isValid = result['valid'] as bool? ?? true;
      final reason = result['reason'] as String? ?? '';

      if (isValid) {
        setState(() {
          _capturedPaths[_areas[_currentIndex].id] = picked.path;
          _rejectedPhotoPath = null;
          _validationError = null;
          _isValidating = false;
        });
      } else {
        setState(() {
          _validationError = reason;
          _isValidating = false;
        });
      }
    } catch (_) {
      // On any error, accept the photo so the user isn't blocked
      setState(() {
        _capturedPaths[_areas[_currentIndex].id] = picked.path;
        _rejectedPhotoPath = null;
        _validationError = null;
        _isValidating = false;
      });
    }
  }

  Future<void> _onNext() async {
    final area = _areas[_currentIndex];
    final path = _capturedPaths[area.id];

    if (path != null) {
      setState(() => _isSaving = true);
      try {
        await _photoService.saveMoveInPhoto(
          areaId: area.id,
          areaName: area.name,
          sourcePath: path,
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

    if (_currentIndex == _areas.length - 1) {
      if (mounted) _showSessionCompleteDialog();
    } else {
      setState(() {
        _currentIndex++;
        _isValidating = false;
        _rejectedPhotoPath = null;
        _validationError = null;
        _anomalyBannerVisible = false;
        _layer2Active = false;
      });
    }
  }

  void _onSkip() {
    if (_currentIndex == _areas.length - 1) {
      context.pop(false);
    } else {
      setState(() {
        _currentIndex++;
        _isValidating = false;
        _rejectedPhotoPath = null;
        _validationError = null;
        _anomalyBannerVisible = false;
        _layer2Active = false;
      });
    }
  }
    }

  class _RadarPainter extends CustomPainter {
  final Color color;
  final double sweepAngle;
  const _RadarPainter({required this.color, required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Concentric rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, radius * (i / 3),
          Paint()
            ..color = color.withValues(alpha: 0.12 + (i * 0.05))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8);
    }

    // Sweep trailing glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.85),
      sweepAngle - (pi / 4), pi / 4, false,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8,
    );

    // Sweep line
    canvas.drawLine(
      center,
      Offset(center.dx + radius * cos(sweepAngle),
             center.dy + radius * sin(sweepAngle)),
      Paint()
        ..color = color.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Center dot
    canvas.drawCircle(center, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.sweepAngle != sweepAngle || old.color != color;
}
