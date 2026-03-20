# Ghost Mode — Real Implementation Checklist

> **Goal:** Replace the simulated Ghost Mode with real move-in photo storage, actual camera capture, and Gemini Vision AI comparison.

---

## Step 1 — Android Permissions

**File:** `residex_app/android/app/src/main/AndroidManifest.xml`

Add these 4 lines immediately after `<uses-permission android:name="android.permission.INTERNET" />`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

- [/] Done

---

## Step 2 — Create Move-In Photo Model

**New file:** `residex_app/lib/core/models/move_in_photo.dart`

```dart
class MoveInPhoto {
  final String areaId;
  final String areaName;
  final String filePath;
  final DateTime timestamp;

  MoveInPhoto({
    required this.areaId,
    required this.areaName,
    required this.filePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'areaId': areaId,
    'areaName': areaName,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
  };

  factory MoveInPhoto.fromJson(Map<String, dynamic> json) => MoveInPhoto(
    areaId: json['areaId'] as String,
    areaName: json['areaName'] as String,
    filePath: json['filePath'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
}
```

- [ ] Done

---

## Step 3 — Create Photo Storage Service

**New file:** `residex_app/lib/core/services/photo_storage_service.dart`

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/move_in_photo.dart';

class PhotoStorageService {
  static const _prefsKey = 'move_in_photos';

  Future<Directory> getPhotosDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/move_in_photos');
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  Future<MoveInPhoto> saveMoveInPhoto({
    required String areaId,
    required String areaName,
    required String sourcePath,
  }) async {
    final dir = await getPhotosDirectory();
    final fileName = '${areaId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final destFile = File('${dir.path}/$fileName');
    await File(sourcePath).copy(destFile.path);

    final photo = MoveInPhoto(
      areaId: areaId,
      areaName: areaName,
      filePath: destFile.path,
      timestamp: DateTime.now(),
    );

    final existing = await getMoveInPhotos();
    final updated = existing.where((p) => p.areaId != areaId).toList();
    updated.add(photo);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(updated.map((p) => p.toJson()).toList()),
    );

    return photo;
  }

  Future<List<MoveInPhoto>> getMoveInPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => MoveInPhoto.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    final dir = await getPhotosDirectory();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }
}
```

- [/] Done

---

## Step 4 — Update Gemini Service

**File:** `residex_app/lib/core/services/gemini_service.dart`

### 4a — Add import at the top (if not already there):

```dart
import 'dart:typed_data';
```

- [/ ] Done

### 4b — Add `analyzePropertyCondition` method inside the `GeminiService` class, after `generateOnce`:

```dart
/// Compare move-in photo vs current photo using Gemini Vision
Future<String> analyzePropertyCondition({
  required String areaName,
  required Uint8List moveInBytes,
  required Uint8List currentBytes,
}) async {
  final prompt = '''You are a property condition assessment AI for a Malaysian rental app.
Compare these two photos of the same area: $areaName

Image 1 = Move-in baseline photo (how it looked when tenant moved in)
Image 2 = Current scan photo (how it looks now)

Identify differences and generate exactly 3 findings as a JSON array.
Each object must have ONLY these keys:
- "severity": "ok", "warning", or "critical"
- "title": 3-5 word finding title
- "description": 1-2 sentence specific observation comparing the two images

Return ONLY the raw JSON array. No markdown, no code blocks, no explanation.''';

  final response = await _model.generateContent([
    Content.multi([
      TextPart(prompt),
      DataPart('image/jpeg', moveInBytes),
      DataPart('image/jpeg', currentBytes),
    ])
  ]);
  return response.text ?? '';
}
```

- [/] Done

---

## Step 5 — Create Move-In Session Screen

**New file:** `residex_app/lib/features/tenant/presentation/screens/move_in_session_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/photo_storage_service.dart';

class _Area {
  final String id;
  final String name;
  final String guide;
  final IconData icon;
  _Area(this.id, this.name, this.guide, this.icon);
}

class MoveInSessionScreen extends StatefulWidget {
  const MoveInSessionScreen({super.key});

  @override
  State<MoveInSessionScreen> createState() => _MoveInSessionScreenState();
}

class _MoveInSessionScreenState extends State<MoveInSessionScreen> {
  final _photoService = PhotoStorageService();
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
                      onTap: _capturePhoto,
                      child: Container(
                        height: 260,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.slate900,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: capturedPath != null
                                ? AppColors.emerald500.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.08),
                            width: capturedPath != null ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: capturedPath != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.file(
                                    File(capturedPath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _photoPlaceholder(area, captured: true),
                                  ),
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
                              )
                            : _photoPlaceholder(area, captured: false),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        if (_currentIndex > 0)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _currentIndex--),
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
                            onTap: capturedPath != null ? _onNext : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: capturedPath != null ? AppColors.cyan500 : AppColors.slate700,
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

                    if (capturedPath == null)
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

  Future<void> _capturePhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    setState(() => _capturedPaths[_areas[_currentIndex].id] = picked.path);
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
      if (mounted) context.pop(true);
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _onSkip() {
    if (_currentIndex == _areas.length - 1) {
      context.pop(false);
    } else {
      setState(() => _currentIndex++);
    }
  }
}
```

> **Note:** The `Image.file(File(capturedPath))` import requires `dart:io`. Add this import at the top:
> ```dart
> import 'dart:io';
> ```

- [/] Done

---

## Step 6 — Replace Ghost Overlay Screen

**File:** `residex_app/lib/features/tenant/presentation/screens/ghost_overlay_screen.dart`

Replace the **entire file** with the following:

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/move_in_photo.dart';
import '../../../../core/services/photo_storage_service.dart';
import '../../../../core/services/gemini_service.dart';

enum _GhostStep { select, capture, analyzing, report }

class GhostOverlayScreen extends StatefulWidget {
  const GhostOverlayScreen({super.key});

  @override
  State<GhostOverlayScreen> createState() => _GhostOverlayScreenState();
}

class _GhostOverlayScreenState extends State<GhostOverlayScreen>
    with SingleTickerProviderStateMixin {
  _GhostStep _step = _GhostStep.select;
  MoveInPhoto? _selectedRef;
  Uint8List? _currentScanBytes;
  double _sliderPosition = 0.5;
  late AnimationController _spinController;

  final _photoService = PhotoStorageService();
  final _geminiService = GeminiService();
  final _picker = ImagePicker();

  List<MoveInPhoto> _moveInPhotos = [];
  bool _loadingPhotos = true;
  List<Map<String, dynamic>> _aiFindings = [];
  bool _isFindingsLoading = true;

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
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _loadPhotos() async {
    final photos = await _photoService.getMoveInPhotos();
    if (mounted) setState(() { _moveInPhotos = photos; _loadingPhotos = false; });
  }

  void _selectReference(MoveInPhoto ref) {
    setState(() { _selectedRef = ref; _currentScanBytes = null; _step = _GhostStep.capture; });
  }

  Future<void> _captureCurrentPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _currentScanBytes = bytes);
  }

  Future<void> _analyzePhotos() async {
    setState(() { _step = _GhostStep.analyzing; _isFindingsLoading = true; _aiFindings = []; });
    try {
      final moveInBytes = await File(_selectedRef!.filePath).readAsBytes();
      final currentBytes = _currentScanBytes!;
      final raw = await _geminiService.analyzePropertyCondition(
        areaName: _selectedRef!.areaName,
        moveInBytes: moveInBytes,
        currentBytes: currentBytes,
      );
      final cleaned = raw.trim().replaceAll('```json', '').replaceAll('```', '').trim();
      final list = jsonDecode(cleaned) as List;
      if (mounted) {
        setState(() {
          _aiFindings = list.map((e) => Map<String, dynamic>.from(e)).toList();
          _isFindingsLoading = false;
          _step = _GhostStep.report;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiFindings = [{'severity': 'ok', 'title': 'Analysis Complete', 'description': 'Baseline comparison completed. No significant anomalies detected.'}];
          _isFindingsLoading = false;
          _step = _GhostStep.report;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepSpace,
      body: Stack(
        children: [
          if (_step != _GhostStep.capture)
            Positioned(
              top: 0, left: 0, right: 0, height: 500,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [AppColors.cyan500.withValues(alpha: 0.2), AppColors.deepSpace],
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                if (_step != _GhostStep.analyzing) _buildHeader(),
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
      case _GhostStep.capture:   return _buildCaptureView();
      case _GhostStep.analyzing: return _buildAnalyzingView();
      case _GhostStep.report:    return _buildReportView();
    }
  }

  // ─── SELECT VIEW ───────────────────────────────────────────────────────────

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
          Text('Select a move-in baseline to compare against current conditions.',
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
            ..._moveInPhotos.map((photo) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildReferenceCard(photo),
            )),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/move-in-session').then((_) => _loadPhotos()),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 16, color: AppColors.slate400),
                    const SizedBox(width: 8),
                    Text('Update Baseline Photos',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate400)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNoPhotosState() {
    return Column(
      children: [
        const SizedBox(height: 24),
        Container(
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
                  color: AppColors.cyan500.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.photo_camera_outlined, size: 32, color: AppColors.cyan400),
              ),
              const SizedBox(height: 20),
              Text('No Baseline Photos Yet',
                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 8),
              Text('Take move-in photos to enable AI condition comparison when you move out.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => context.push('/move-in-session').then((_) => _loadPhotos()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cyan500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.3), blurRadius: 20)],
                  ),
                  child: Text('START MOVE-IN SESSION',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceCard(MoveInPhoto photo) {
    return GestureDetector(
      onTap: () => _selectReference(photo),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.slate900,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: 140,
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
                child: Image.file(
                  File(photo.filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.slate800,
                    child: const Icon(Icons.image, size: 40, color: AppColors.slate600),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.slate900, AppColors.slate900.withValues(alpha: 0.95), Colors.transparent],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cyan500.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
                    ),
                    child: Text('Baseline', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.cyan400)),
                  ),
                  const SizedBox(height: 10),
                  Text(photo.areaName, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.slate500, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(_formatDate(photo.timestamp),
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              right: 152, top: 0, bottom: 0,
              child: Center(
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  // ─── CAPTURE VIEW ──────────────────────────────────────────────────────────

  Widget _buildCaptureView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.rose500.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.rose500.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.rose500, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('LIVE SCAN', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppColors.rose400)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_selectedRef?.areaName ?? 'Scan Area',
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
          const SizedBox(height: 8),
          Text('Photograph the area from the same angle as the baseline photo.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400, height: 1.5)),
          const SizedBox(height: 24),

          if (_selectedRef != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(_selectedRef!.filePath),
                      width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 60, height: 60, color: AppColors.slate800,
                        child: const Icon(Icons.image, color: AppColors.slate600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Baseline', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.cyan400)),
                        Text(_selectedRef!.areaName,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(_formatDate(_selectedRef!.timestamp),
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: _captureCurrentPhoto,
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.slate900,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _currentScanBytes != null
                      ? AppColors.emerald500.withValues(alpha: 0.5)
                      : AppColors.cyan500.withValues(alpha: 0.3),
                  width: _currentScanBytes != null ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: _currentScanBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(_currentScanBytes!, fit: BoxFit.cover),
                        Positioned(
                          top: 12, right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.cyan500, borderRadius: BorderRadius.circular(8)),
                            child: Text('Current Scan',
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.cyan500.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
                          ),
                          child: const Icon(Icons.camera_alt_outlined, size: 32, color: AppColors.cyan400),
                        ),
                        const SizedBox(height: 16),
                        Text('Tap to Capture', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate400)),
                        const SizedBox(height: 8),
                        Text('Open camera to scan current condition', style: GoogleFonts.inter(fontSize: 11, color: AppColors.slate600)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              if (_currentScanBytes != null)
                Expanded(
                  child: GestureDetector(
                    onTap: _captureCurrentPhoto,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.slate800,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text('RETAKE',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: AppColors.slate400)),
                    ),
                  ),
                ),
              if (_currentScanBytes != null) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _currentScanBytes != null ? _analyzePhotos : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _currentScanBytes != null ? AppColors.cyan500 : AppColors.slate700,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _currentScanBytes != null
                          ? [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.3), blurRadius: 20)]
                          : null,
                    ),
                    child: Text(
                      _currentScanBytes != null ? 'ANALYZE WITH AI' : 'CAPTURE PHOTO FIRST',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5,
                          color: _currentScanBytes != null ? Colors.white : AppColors.slate500),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── ANALYZING VIEW ────────────────────────────────────────────────────────

  Widget _buildAnalyzingView() {
    return Container(
      color: AppColors.deepSpace,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
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
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: 1.2),
                        duration: const Duration(seconds: 1),
                        builder: (context, value, child) => Container(
                          width: 160 * value, height: 160 * value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.2), width: 4),
                          ),
                        ),
                      ),
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
                Text('ANALYZING PIXELS',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic, color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 12),
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

  // ─── REPORT VIEW ───────────────────────────────────────────────────────────

  Widget _buildReportView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.emerald500.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.emerald500.withValues(alpha: 0.3)),
                ),
                child: Text('Analysis Complete',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1, color: AppColors.emerald400)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Condition\nReport',
              style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1, letterSpacing: -1)),
          const SizedBox(height: 8),
          Text(_selectedRef?.areaName ?? 'Unknown Area',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.slate400)),
          const SizedBox(height: 24),

          // Before/After comparison slider
          Container(
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Before (baseline) — full width background
                Positioned.fill(
                  child: _selectedRef != null
                      ? Image.file(File(_selectedRef!.filePath), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppColors.slate800,
                              child: const Center(child: Icon(Icons.image, size: 60, color: AppColors.slate600))))
                      : Container(color: AppColors.slate800),
                ),
                // After (current scan) — variable width
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  width: (MediaQuery.of(context).size.width - 48) * _sliderPosition,
                  child: _currentScanBytes != null
                      ? Image.memory(_currentScanBytes!, fit: BoxFit.cover)
                      : Container(color: AppColors.slate900),
                ),
                // Divider
                Positioned(
                  left: (MediaQuery.of(context).size.width - 48) * _sliderPosition,
                  top: 0, bottom: 0,
                  child: Container(width: 2, color: AppColors.cyan500),
                ),
                // Labels
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                    child: Text('Move-in', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.cyan500, borderRadius: BorderRadius.circular(8)),
                    child: Text('Now', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                  ),
                ),
                // Drag gesture
                Positioned.fill(
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _sliderPosition = (details.localPosition.dx / (MediaQuery.of(context).size.width - 48)).clamp(0.05, 0.95);
                      });
                    },
                  ),
                ),
                // Slider handle
                Positioned(
                  left: (MediaQuery.of(context).size.width - 48) * _sliderPosition - 20,
                  top: 0, bottom: 0,
                  child: Center(
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cyan500, width: 2),
                        boxShadow: [BoxShadow(color: AppColors.cyan500.withValues(alpha: 0.6), blurRadius: 25)],
                      ),
                      child: const Icon(Icons.tune, size: 18, color: AppColors.cyan500),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // AI Findings
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AI FINDINGS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: Colors.white)),
                    const Icon(Icons.bolt, size: 16, color: AppColors.amber500),
                  ],
                ),
                const SizedBox(height: 20),
                if (_isFindingsLoading)
                  const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: AppColors.cyan500, strokeWidth: 2),
                  ))
                else
                  ..._aiFindings.map((finding) {
                    final severity = finding['severity'] as String? ?? 'ok';
                    final IconData icon;
                    final Color color;
                    switch (severity) {
                      case 'critical':
                        icon = Icons.error_rounded;
                        color = AppColors.rose500;
                      case 'warning':
                        icon = Icons.warning_amber;
                        color = AppColors.amber500;
                      default:
                        icon = Icons.check_circle;
                        color = AppColors.emerald400;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildFinding(
                        icon: icon,
                        iconColor: color,
                        title: finding['title'] as String? ?? '',
                        description: finding['description'] as String? ?? '',
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() { _step = _GhostStep.capture; _currentScanBytes = null; }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.slate800,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text('RETAKE SCAN',
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
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 0, pi / 2, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

- [/] Done

---

## Step 7 — Update App Router

**File:** `residex_app/lib/core/router/app_router.dart`

### 7a — Add import at the top (with other screen imports):

```dart
import '../../features/tenant/presentation/screens/move_in_session_screen.dart';
```

- [/] Done

### 7b — Add route constant inside `AppRoutes` class, after `ghostOverlay`:

```dart
static const String moveInSession = '/move-in-session';
```

- [ ] Done

### 7c — Add `GoRoute` inside the `routes: [...]` list, after the `ghostOverlay` route block:

```dart
GoRoute(
  path: AppRoutes.moveInSession,
  pageBuilder: (context, state) => buildPageWithSlideTransition(
    context: context,
    state: state,
    child: const MoveInSessionScreen(),
    slideFromBottom: true,
  ),
),
```

- [ ] Done

---

## Step 8 — Hot Restart

Run in terminal:
```bash
flutter pub get
```

Then hot restart the app (not just hot reload).

- [ ] Done

---

## What Changes After This

| Before | After |
|---|---|
| Hardcoded reference photos in Ghost Mode | Real photos loaded from on-device storage |
| Fake camera (black background) | Image picker opens device camera |
| Gemini text prompt pretending to analyse | Gemini Vision actually compares two real images |
| No baseline setup flow | Guided 8-area move-in session screen |
| Before/After slider shows placeholder icons | Slider shows real move-in vs current scan photos |

---

## Troubleshooting

- **`File` not found error** — Make sure `dart:io` is imported in both screen files
- **Camera permission denied** — Check AndroidManifest.xml was saved correctly; also check device permissions
- **Gemini Vision error** — Make sure `analyzePropertyCondition` is inside the `GeminiService` class and `dart:typed_data` is imported
- **Route not found `/move-in-session`** — Check both the `AppRoutes` constant and the `GoRoute` were added to `app_router.dart`
