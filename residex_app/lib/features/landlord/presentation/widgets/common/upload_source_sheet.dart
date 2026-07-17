import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_theme.dart';

/// A picked upload, regardless of source (camera, photo library or files).
class PickedUpload {
  final String path;
  final String name;
  const PickedUpload({required this.path, required this.name});
}

/// Bottom sheet offering the three upload sources. Returns null when the
/// user dismisses the sheet or cancels the underlying picker.
Future<PickedUpload?> showUploadSourceSheet(BuildContext context) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(sheetContext, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose photo'),
            onTap: () => Navigator.pop(sheetContext, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Choose file'),
            onTap: () => Navigator.pop(sheetContext, 'file'),
          ),
        ],
      ),
    ),
  );
  if (source == null) return null;

  if (source == 'file') {
    // Any-file picker for cloud-provider compatibility (e.g. Google Drive);
    // extension enforcement stays with the caller via isAllowedUploadFilename.
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    final picked = result?.files.single;
    if (picked == null || picked.path == null) return null;
    return PickedUpload(path: picked.path!, name: picked.name);
  }

  final image = await ImagePicker().pickImage(
    source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 85,
  );
  if (image == null) return null;
  return PickedUpload(path: image.path, name: image.name);
}
