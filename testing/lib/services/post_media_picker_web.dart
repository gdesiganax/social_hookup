// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

class PickedPostImage {
  const PickedPostImage({
    required this.name,
    required this.bytes,
    required this.mimeType,
  });

  final String name;
  final Uint8List bytes;
  final String mimeType;
}

Future<PickedPostImage?> pickPostImage() {
  final completer = Completer<PickedPostImage?>();
  final input = html.FileUploadInputElement()
    ..accept = 'image/jpeg,image/png,image/webp,image/gif'
    ..multiple = false;

  input.onChange.first.then((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }

    final file = files.first;
    final reader = html.FileReader();
    reader.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError('Could not read the selected image.');
      }
    });
    reader.onLoad.first.then((_) {
      final result = reader.result;
      final Uint8List bytes;
      if (result is Uint8List) {
        bytes = result;
      } else if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else {
        completer.completeError('Could not read the selected image.');
        return;
      }
      completer.complete(
        PickedPostImage(
          name: file.name,
          bytes: bytes,
          mimeType: file.type.isEmpty ? 'application/octet-stream' : file.type,
        ),
      );
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
