import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 照片存取：从相册/拍照选一张，拷贝进应用私有 photos 目录。
/// DB 只存文件绝对路径。
class PhotoStore {
  PhotoStore([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static Future<Directory> _photosDir() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'photos')).create(recursive: true);
  }

  /// 选一张照片并入库；用户取消返回 null。
  Future<String?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final dir = await _photosDir();
    final dest = p.join(
      dir.path,
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(picked.path)}',
    );
    return File(picked.path).copy(dest).then((f) => f.path);
  }

  /// 删除照片文件（忽略不存在）。
  static Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // 文件已不存在则忽略
    }
  }
}
