import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadFile(File file, String path) async {
    final ref = _storage.ref(path);
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }
}
