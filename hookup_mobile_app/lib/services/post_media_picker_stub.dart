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

Future<PickedPostImage?> pickPostImage() async => null;
