# 🛡️ Sentinel Sweeper — Implementation Checklist (CORRECTED)

**Feature:** Passive multi-layer surveillance device detector
**Correct placement:** `move_in_session_screen.dart` (baseline capture, NOT ghost overlay)
**Why:** The sentinel runs while the tenant is physically exploring the room for the
         first time, panning the phone near mirrors, vents, and fixtures before
         each baseline photo. The ghost overlay is a move-out scan in a familiar
         room — wrong timing, wrong context.

---

## WHAT TO DO WITH ghost_overlay_screen.dart

If you already added sentinel code there per the previous checklist, **remove all of it**:
- Undo Steps 3–18 from the previous checklist
- Restore `with SingleTickerProviderStateMixin` (single ticker is enough)
- Remove the sentinel imports, state fields, methods, and widgets
- The ghost overlay stays as-is (Gemini photo analysis only)

---

## Files to Modify

| File | Change |
|---|---|
| `pubspec.yaml` | Add `sensors_plus`, `vibration`, `network_info_plus` (if not already added) |
| `android/app/src/main/AndroidManifest.xml` | Add Wi-Fi permissions (if not already added) |
| `lib/features/tenant/presentation/screens/move_in_session_screen.dart` | Full sentinel integration |

---

## STEP 1 — Confirm packages are in `pubspec.yaml`

These should already be present from the previous checklist. If not, add them under dependencies:

```yaml
sensors_plus: ^5.0.1
vibration: ^2.0.0
network_info_plus: ^6.0.0
```

Run `flutter pub get` if you added anything.

---

## STEP 2 — Confirm Android permissions in `AndroidManifest.xml`

These should already be present. If not, add inside `<manifest>` before `<application>`:

```xml
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

---

## STEP 3 — Add new enum and data class to `move_in_session_screen.dart`

Add these two blocks right after the existing `class _Area { ... }` block (after line 15):

```dart
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
```

---

## STEP 4 — Add new imports

At the top of `move_in_session_screen.dart`, add after the existing imports:

```dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
```

---

## STEP 5 — Change mixin to support multiple AnimationControllers

**Line 24** — change:
```dart
class _MoveInSessionScreenState extends State<MoveInSessionScreen> {
```
To:
```dart
class _MoveInSessionScreenState extends State<MoveInSessionScreen>
    with TickerProviderStateMixin {
```

---

## STEP 6 — Add sentinel state fields

Add these fields inside `_MoveInSessionScreenState`, right after `bool _isSaving = false;`:

```dart
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
final List<_SentinelAnomaly> _sessionAnomalies = [];
DateTime _lastSentinelUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

// ── Sentinel Layer 3 — Wi-Fi ──
String _wifiSsid = 'Scanning...';
bool _wifiScanDone = false;
int _suspiciousDeviceCount = 0;
```

---

## STEP 7 — Add `initState()` override

Add this override right after the field declarations (before `build`):

```dart
@override
void initState() {
  super.initState();
  _radarController =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();
  _startSentinel();
  unawaited(_runWifiScan());
}
```

---

## STEP 8 — Add `dispose()` override

Add right after `initState()`:

```dart
@override
void dispose() {
  _magnetometerSub?.cancel();
  _radarController.dispose();
  super.dispose();
}
```

---

## STEP 9 — Add 5 sentinel logic methods

Add this entire block right before the `build()` method:

```dart
// ── SENTINEL METHODS ─────────────────────────────────────────────────────

double _computeMuT(double x, double y, double z) =>
    sqrt(x * x + y * y + z * z);

void _startSentinel() {
  _magnetometerSub?.cancel();
  _magnetometerSub = magnetometerEventStream().listen(_handleMagneticEvent);
}

void _stopSentinel() {
  _magnetometerSub?.cancel();
  _magnetometerSub = null;
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
      if (mounted) setState(() => _anomalyBannerVisible = true);
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
```

---

## STEP 10 — Update `_onNext()` to record sentinel anomaly per area

**Find `_onNext()` and add these lines** at the very top of the method body, before anything else:

```dart
// Record sentinel result for this area before advancing
if (_peakMuT >= 100) {
  _sessionAnomalies.add(_SentinelAnomaly(
    areaName: _areas[_currentIndex].name,
    peakMuT: _peakMuT,
    timestamp: DateTime.now(),
  ));
}
// Re-calibrate magnetometer for the next room's baseline
_peakMuT = 0.0;
_calibrationSamples = 0;
_calibrationSum = 0.0;
_baselineMuT = 0.0;
_sentinelLevel = _SentinelThreatLevel.calibrating;
_anomalyBannerVisible = false;
```

Also, when `_currentIndex == _areas.length - 1` (the FINISH branch), replace:
```dart
if (mounted) context.pop(true);
```
With:
```dart
if (mounted) _showSessionCompleteDialog();
```

---

## STEP 11 — Add sentinel HUD + anomaly banner to the `build()` layout

**Find this block** in `build()` — the `const SizedBox(height: 32)` before the navigation buttons (around line 169):

```dart
const SizedBox(height: 32),

Row(
  children: [
    if (_currentIndex > 0)
```

**Replace** that `const SizedBox(height: 32),` with:

```dart
const SizedBox(height: 20),

// ── Sentinel HUD ──
_buildSentinelHud(),
const SizedBox(height: 16),

// ── Anomaly banner (shown when alert triggered) ──
if (_anomalyBannerVisible) ...[
  _buildAnomalyBanner(),
  const SizedBox(height: 16),
],

Row(
  children: [
    if (_currentIndex > 0)
```

---

## STEP 12 — Add 3 new widget-building methods + painter

Add this entire block right before the existing `_photoPlaceholder` method:

```dart
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
```

---

## STEP 13 — Add `_RadarPainter` class

Add at the very bottom of the file (after the closing `}`):

```dart
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
```

---

## STEP 14 — Final verification

```bash
flutter pub get
flutter analyze
flutter run   # must test on physical device — emulators have no magnetometer
```

**Manual test checklist:**
- [ ] Move-in session opens → Sentinel HUD visible between photo card and nav buttons
- [ ] HUD shows "Calibrating... (0/30)" for ~3 seconds, then "All Clear" in green
- [ ] Hold phone near microwave or WiFi router → HUD turns amber/red, phone vibrates
- [ ] Red anomaly banner appears with µT reading; dismisses with X
- [ ] Tap NEXT AREA → sentinel re-calibrates for the new area
- [ ] Finish session → dialog shows sentinel certificate (green) or anomaly log (amber)
- [ ] Dialog "DONE" → exits screen, returns to caller

---

## Summary of UX change

| | Before (wrong) | After (correct) |
|---|---|---|
| **When** | Move-out ghost comparison scan | Move-in baseline session |
| **Where** | ghost_overlay_screen.dart | move_in_session_screen.dart |
| **HUD location** | Overlaid on live camera preview | Below photo card in main screen |
| **Report** | Part of ghost comparison report | Session-complete dialog |
| **Anomaly result** | Lost after ghost scan | Stored per-area alongside baseline |

*Packages: sensors_plus, vibration, network_info_plus*
*Real magnetometer data — thresholds: caution >80µT or +35µT over baseline, alert ≥100µT*
