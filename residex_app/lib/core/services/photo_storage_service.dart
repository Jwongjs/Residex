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